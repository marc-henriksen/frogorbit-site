// Aggregate-only analytics. No cookies, sessions, account IDs or browser identifiers.
const endpoint='https://pvtwxtnbsospauqkrbek.supabase.co/rest/v1/rpc/record_product_event';
const key='sb_publishable_I2QGmFehSnVkANPPWNaxkQ_dQLBvSh_';
export function track(event,page,jobId=null){
  // Best effort: analytics must never interrupt the site.
  try{
    fetch(endpoint,{method:'POST',mode:'cors',credentials:'omit',keepalive:true,
      headers:{'apikey':key,'Content-Type':'application/json'},
      body:JSON.stringify({p_event:event,p_page:page,p_job_id:jobId})
    }).catch(()=>{});
  }catch(_){}
}
