const CloudSync=(()=>{
 let channel=null,timer=null,running=false;
 async function sync(){if(running)return;running=true;try{await KDB.sync();}finally{running=false;}}
 function start(){
  if(channel)return;
  channel=KStaff.connect().channel('kervan-central-data').on('postgres_changes',{event:'*',schema:'public'},()=>{clearTimeout(timer);timer=setTimeout(()=>sync().catch(report),150);}).subscribe();
  setInterval(()=>{if(navigator.onLine)sync().catch(report);},5000);
  window.addEventListener('online',()=>sync().catch(report));window.addEventListener('focus',()=>sync().catch(report));
 }
 function report(error){window.dispatchEvent(new CustomEvent('kervan:sync-error',{detail:error.message}));}
 return {sync,start,connect:()=>KStaff.connect()};
})();
