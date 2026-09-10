#!/usr/bin/env bash
set -euo pipefail
BASE=https://gibnvcducxqyrfvrtbub.supabase.co
KEY=$(sed -n "s/ const key='\([^']*\)';/\1/p" js/staff.js)
email(){ printf %s "$1" | od -An -tx1 | tr -d ' \n'; printf %s '@staff.kervan.invalid'; }
login(){ curl -fsS --max-time 40 -X POST "$BASE/auth/v1/token?grant_type=password" -H "apikey: $KEY" -H 'Content-Type: application/json' --data "{\"email\":\"$(email "$1")\",\"password\":\"Kervan-PIN:$2\"}"|jq -r .access_token; }
api(){ local token=$1 path=$2; shift 2; curl -fsS --max-time 40 "$BASE$path" -H "apikey: $KEY" -H "Authorization: Bearer $token" "$@"; }
rpc(){ local token=$1 table=$2 key=$3 base=$4 data=$5 mutation; mutation=$(cat /proc/sys/kernel/random/uuid); api "$token" /rest/v1/rpc/apply_change -X POST -H 'Content-Type: application/json' --data "{\"p_table\":\"$table\",\"p_key\":\"$key\",\"p_data\":$data,\"p_base\":$base,\"p_mutation\":\"$mutation\"}"; }
ADMIN=$(login admin 1453); test "$ADMIN" != null
SUFFIX=$(date +%s); USER=e2e_phone_$SUFFIX; SID=e2e_supplier_$SUFFIX; BAR=869999$SUFFIX; RID=e2e_receipt_$SUFFIX; LID=e2e_line_$SUFFIX
CREATED=$(api "$ADMIN" /functions/v1/manage-staff -X POST -H 'Content-Type: application/json' --data "{\"action\":\"create\",\"username\":\"$USER\",\"name\":\"E2E Telefon\",\"role\":\"PERSONNEL\"}")
PERSON_ID=$(jq -r .user.id<<<"$CREATED"); test "$PERSON_ID" != null
PHONE=$(login "$USER" 1453); test "$PHONE" != null; echo 'PASS personnel default PIN 1453'
SUP=$(rpc "$ADMIN" suppliers "$SID" null '{"name":"E2E PC Tedarikçi","phone":"555"}'); SBASE=$(jq -r '.row.updated_at|@json'<<<"$SUP")
VISIBLE=$(api "$PHONE" "/rest/v1/suppliers?local_id=eq.$SID&select=name,local_id,deleted_at"); test "$(jq -r '.[0].name'<<<"$VISIBLE")" = 'E2E PC Tedarikçi'; echo 'PASS PC supplier visible to phone personnel'
STATUS=$(curl -sS -o /tmp/kervan-denied.json -w '%{http_code}' --max-time 40 "$BASE/rest/v1/rpc/apply_change" -H "apikey: $KEY" -H "Authorization: Bearer $PHONE" -H 'Content-Type: application/json' --data "{\"p_table\":\"suppliers\",\"p_key\":\"denied-$SUFFIX\",\"p_data\":{\"name\":\"Denied\"},\"p_base\":null,\"p_mutation\":\"$(cat /proc/sys/kernel/random/uuid)\"}"); test "$STATUS" -ge 400; echo 'PASS personnel supplier/admin write denied by server'
PROD=$(rpc "$ADMIN" products "$BAR" null "{\"barcode\":\"$BAR\",\"product_code\":\"E2E\",\"product_name\":\"E2E Ürün\",\"unit\":\"KOLI\",\"case_quantity\":10,\"manually_added\":false}"); PBASE=$(jq -r '.row.updated_at|@json'<<<"$PROD")
REC=$(rpc "$PHONE" receipts "$RID" null "{\"supplier_id\":\"$SID\",\"supplier_name\":\"E2E PC Tedarikçi\",\"invoice_number\":\"E2E-$SUFFIX\",\"receipt_date\":\"2026-09-10\",\"employee_id\":\"$PERSON_ID\",\"employee_name\":\"E2E Telefon\",\"status\":\"draft\"}"); RBASE=$(jq -r '.row.updated_at|@json'<<<"$REC")
LINE=$(rpc "$PHONE" receipt_lines "$LID" null "{\"receipt_id\":\"$RID\",\"barcode\":\"$BAR\",\"product_code\":\"E2E\",\"product_name\":\"E2E Ürün\",\"entered_quantity\":2,\"entered_unit\":\"KOLI\",\"conversion_quantity\":10,\"total_units\":999}"); LBASE=$(jq -r '.row.updated_at|@json'<<<"$LINE"); test "$(jq -r .row.total_units<<<"$LINE")" = 20; echo 'PASS quantity conversion enforced server-side'
LINE2=$(rpc "$PHONE" receipt_lines "$LID" "$LBASE" "{\"receipt_id\":\"$RID\",\"barcode\":\"$BAR\",\"product_code\":\"E2E\",\"product_name\":\"E2E Ürün\",\"entered_quantity\":3,\"entered_unit\":\"KOLI\",\"conversion_quantity\":10}"); LBASE2=$(jq -r '.row.updated_at|@json'<<<"$LINE2"); test "$(jq -r .row.total_units<<<"$LINE2")" = 30; echo 'PASS repeated scan/merged quantity update'
DONE=$(rpc "$PHONE" receipts "$RID" "$RBASE" "{\"supplier_id\":\"$SID\",\"supplier_name\":\"E2E PC Tedarikçi\",\"invoice_number\":\"E2E-$SUFFIX\",\"receipt_date\":\"2026-09-10\",\"employee_id\":\"$PERSON_ID\",\"employee_name\":\"E2E Telefon\",\"status\":\"completed\"}"); RBASE2=$(jq -r '.row.updated_at|@json'<<<"$DONE"); test "$(jq -r .row.total_units<<<"$DONE")" = 30
PCREC=$(api "$ADMIN" "/rest/v1/receipts?local_id=eq.$RID&select=invoice_number,status,total_units"); test "$(jq -r '.[0].status'<<<"$PCREC")" = completed; echo 'PASS phone receipt visible to PC admin'
STALE=$(rpc "$ADMIN" receipts "$RID" "$RBASE" "{\"description\":\"stale overwrite\"}"); test "$(jq -r .status<<<"$STALE")" = conflict; echo 'PASS stale-device conflict rejected'
TOMB=$(rpc "$ADMIN" suppliers "$SID" "$SBASE" '{"deleted_at":"2026-09-10T00:00:00Z"}'); test "$(jq -r '.row.deleted_at!=null'<<<"$TOMB")" = true
STALE2=$(rpc "$ADMIN" suppliers "$SID" "$SBASE" '{"name":"resurrected"}'); test "$(jq -r .status<<<"$STALE2")" = conflict; echo 'PASS tombstone prevents resurrection'
api "$ADMIN" /functions/v1/manage-staff -X POST -H 'Content-Type: application/json' --data "{\"action\":\"role\",\"id\":\"$PERSON_ID\",\"role\":\"ADMIN\"}" >/dev/null
test "$(api "$PHONE" "/rest/v1/staff?id=eq.$PERSON_ID&select=role"|jq -r '.[0].role')" = ADMIN
api "$ADMIN" /functions/v1/manage-staff -X POST -H 'Content-Type: application/json' --data "{\"action\":\"role\",\"id\":\"$PERSON_ID\",\"role\":\"PERSONNEL\"}" >/dev/null
api "$ADMIN" /functions/v1/manage-staff -X POST -H 'Content-Type: application/json' --data "{\"action\":\"resetPin\",\"id\":\"$PERSON_ID\",\"pin\":\"1453\"}" >/dev/null
api "$ADMIN" /functions/v1/manage-staff -X POST -H 'Content-Type: application/json' --data "{\"action\":\"toggle\",\"id\":\"$PERSON_ID\",\"active\":false}" >/dev/null
echo 'PASS role change, PIN reset, activation management'
echo 'PASS central end-to-end test completed'
