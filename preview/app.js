'use strict';
    // A UI demonstration only. Native GPS filtering remains in MileageCore.
    const STORAGE_KEY = 'mileage-browser-preview-v1';
const APPEARANCE_KEY = document.documentElement.dataset.appearanceKey;
let appearance = document.documentElement.dataset.theme || 'system';
function syncAppearanceControls() {
  document.querySelectorAll('[data-appearance-select]').forEach(select => select.value = appearance);
  document.querySelector('meta[name="theme-color"]').content = getComputedStyle(document.documentElement).getPropertyValue('--color-background').trim();
}
function setAppearance(value) {
  if (!['system', 'light', 'dark'].includes(value)) return;
  appearance = value;
  document.documentElement.dataset.theme = value;
  try { localStorage.setItem(APPEARANCE_KEY, value); } catch (_) { /* Appearance still works for this session. */ }
  syncAppearanceControls();
}
window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', syncAppearanceControls);
syncAppearanceControls();
    const icons = {
      route:'<path d="M7 5a2 2 0 1 1-4 0 2 2 0 0 1 4 0Zm14 14a2 2 0 1 1-4 0 2 2 0 0 1 4 0ZM5 7v6a4 4 0 0 0 4 4h6a4 4 0 0 0 4-4V9a4 4 0 0 0-4-4h-4"/>',
      settings:'<path d="M4 7h9m4 0h3M4 17h3m4 0h9"/><circle cx="15" cy="7" r="2"/><circle cx="9" cy="17" r="2"/>',
      navigation:'<path d="m12 3 8 18-8-5-8 5 8-18Z"/>',play:'<path d="m8 5 11 7-11 7V5Z" fill="currentColor" stroke="none"/>',stop:'<rect x="6" y="6" width="12" height="12" rx="1" fill="currentColor" stroke="none"/>',
      briefcase:'<rect x="3" y="7" width="18" height="14" rx="3"/><path d="M8 7V5a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M3 12a22 22 0 0 0 18 0M12 11v4"/>',
      car:'<path d="m5 9 2-5h10l2 5M3 10h18v8H3v-8Zm2 8v3m14-3v3M6 13h2m8 0h2"/>',chevron:'<path d="m9 5 7 7-7 7"/>',back:'<path d="m15 5-7 7 7 7"/>',
      chart:'<path d="M4 3v17h17M8 16v-4m5 4V8m5 8V4"/>',shield:'<path d="m12 3 8 3v6c0 5-8 9-8 9s-8-4-8-9V6l8-3Z"/><path d="m8 12 3 3 5-6"/>',export:'<path d="M5 10v10h14V10M12 15V3m-4 4 4-4 4 4"/>',
      signal:'<path d="M4 19v-3m5 3v-6m5 6V9m5 10V5" stroke-width="3"/>',wifi:'<path d="M3 9a14 14 0 0 1 18 0M6 13a9 9 0 0 1 12 0m-9 4a4 4 0 0 1 6 0m-3 3h.01"/>',battery:'<rect x="2" y="6" width="18" height="12" rx="3"/><path d="M23 10v4"/><rect x="5" y="9" width="12" height="6" rx="1" fill="currentColor" stroke="none"/>',check:'<path d="m5 12 4 4L19 6"/>',clock:'<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>'
    };
    const icon = (name,size=20) => `<svg width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.65" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${icons[name] || icons.route}</svg>`;
    document.querySelectorAll('[data-icon]').forEach(el => el.innerHTML=icon(el.dataset.icon,el.closest('.status-icons')?15:21));
    const esc = value => String(value ?? '').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
    const app=document.getElementById('app'), sheet=document.getElementById('sheet');
    let sheetOpener = null;
    sheet.addEventListener('click', event => {
      if (event.target !== sheet) return;
      const bounds = sheet.getBoundingClientRect();
      if (event.clientX < bounds.left || event.clientX > bounds.right || event.clientY < bounds.top || event.clientY > bounds.bottom) sheet.close();
    });
    // Native <dialog> traps focus and handles Escape. Restore a recreated trigger after saving.
    sheet.addEventListener('close', () => {
      if (sheetOpener?.element?.isConnected) sheetOpener.element.focus({preventScroll: true});
      else if (sheetOpener?.action) {
        const target = [...document.querySelectorAll('[data-action]')].find(element => element.dataset.action === sheetOpener.action && (!sheetOpener.id || element.dataset.id === sheetOpener.id));
        if (target) target.focus({preventScroll: true});
        else {
          const heading = app.querySelector('h1');
          if (heading) { heading.tabIndex = -1; heading.focus({preventScroll: true}); }
        }
      }
      sheetOpener = null;
    });
    let trips=[],storageError='',readOnly=false,view='home',selectedId=null,filter='All',query='',category='Business',purpose='',toastTimer;
    try {
      const raw=localStorage.getItem(STORAGE_KEY);
      if(raw) {
        const saved=JSON.parse(raw);
        if(saved.version!==1 || !Array.isArray(saved.trips) || !saved.trips.every(t=>t && typeof t.id==='string' && ['Business','Personal'].includes(t.category) && Number.isFinite(t.gpsMiles) && Array.isArray(t.issues) && Number.isFinite(Date.parse(t.startedAt)))) throw Error('Invalid preview records');
        trips=saved.trips;
        trips.filter(t=>!t.endedAt).forEach(t=>{t.interrupted=true;if(!t.issues.includes('Preview reloaded during trip'))t.issues.push('Preview reloaded during trip');t.reviewed=false;});
      }
    } catch(error){readOnly=true;storageError='Preview storage could not be opened. Existing data has been kept. Exports remain available.';}
    const active=()=>trips.find(t=>!t.endedAt);
    const completed=()=>trips.filter(t=>t.endedAt).sort((a,b)=>Date.parse(b.startedAt)-Date.parse(a.startedAt));
    const miles=t=>t.adjustedMiles ?? t.gpsMiles;
    const needsReview=t=>t.issues.length>0&&!t.reviewed;
    function commit(next){
      if(readOnly)return false;
      try {localStorage.setItem(STORAGE_KEY,JSON.stringify({version:1,source:'simulated-browser-preview',trips:next}));trips=next;storageError='';return true;}
      catch(error){readOnly=true;storageError='This browser could not save the preview. Recording has stopped. Export your preview data before continuing.';render();return false;}
    }
    const formatDate=(date,full=false)=>new Date(date).toLocaleString(undefined,{month:'short',day:'numeric',...(full?{year:'numeric'}:{}),hour:'numeric',minute:'2-digit'});
    const time=seconds=>[Math.floor(seconds/3600),Math.floor(seconds/60)%60,Math.floor(seconds)%60].map(n=>String(n).padStart(2,'0')).join(':');
    function toast(message){const el=document.getElementById('toast');el.textContent=message;el.hidden=false;clearTimeout(toastTimer);toastTimer=setTimeout(()=>el.hidden=true,3500);}
    function go(next,id=null){view=next;selectedId=id;render();document.getElementById('screen').scrollTop=0;window.scrollTo(0,0);const heading=app.querySelector('h1');if(heading){heading.tabIndex=-1;heading.focus({preventScroll:true});}}
    function segments(values,selected,action){return `<div class="segment" role="group" aria-label="${action==='category'?'Trip type':'Filter trips'}">${values.map(v=>`<button type="button" class="${selected===v?'selected':''}" aria-pressed="${selected===v}" data-action="${action}" data-value="${v}">${v}</button>`).join('')}</div>`;}
    function row(t){return `<button class="trip-row" data-action="detail" data-id="${esc(t.id)}" aria-label="${esc(t.purpose||t.category+' trip')}, ${miles(t).toFixed(2)} miles"><span class="trip-icon">${icon(t.category==='Business'?'briefcase':'car')}</span><span class="trip-copy"><span class="trip-title">${esc(t.purpose||t.category+' trip')}</span><span class="trip-date">${esc(formatDate(t.startedAt))}</span>${needsReview(t)?'<span class="trip-review">Needs review</span>':''}</span><span class="trip-miles">${miles(t).toFixed(2)}<small>miles</small></span><span class="muted">${icon('chevron',12)}</span></button>`;}
    function empty(title,text){return `<div class="empty"><span class="muted">${icon('route',36)}</span><h3>${title}</h3><p>${text}</p></div>`;}
    function render(){
      const warning=storageError?`<div role="alert" class="storage-warning">${esc(storageError)}</div>`:'';
      if(view==='home')renderHome(warning);
      else if(view==='history')renderHistory(warning);
      else renderDetail(warning);
    }
    function renderHome(warning) {
      const t = active(), month = new Date();
      const monthTrips = completed().filter(t => {
        const date = new Date(t.startedAt);
        return date.getMonth() === month.getMonth() && date.getFullYear() === month.getFullYear();
      });
      const card = t ? `
        <section class="card" aria-label="Active simulated trip">
          <div class="flex between"><span class="recording-label ${t.interrupted ? 'orange' : 'green'}"><span class="dot"></span>${t.interrupted ? 'Recording interrupted' : 'Recording trip'}</span><small class="muted">${t.category}</small></div>
          <div class="big-number"><span id="live-miles">${t.gpsMiles.toFixed(2)}</span><small>mi</small></div>
          <div class="recording-meta">
            <p class="muted">Started ${new Date(t.startedAt).toLocaleTimeString(undefined, {hour: 'numeric', minute: '2-digit'})} · <span id="elapsed">${time(t.demoSeconds || 0)}</span> simulated elapsed</p>
            <p class="${t.interrupted ? 'orange' : 'green'}">${icon('navigation', 14)} ${t.interrupted ? 'Resume to continue the simulation' : 'Simulated GPS signal · 10× speed'}</p>
          </div>
          ${t.purpose ? `<h3>${esc(t.purpose)}</h3>` : ''}
          ${t.interrupted ? `<button class="button full" data-action="resume" ${readOnly ? 'disabled' : ''}>${icon('play',16)}Resume trip</button>` : ''}
          <button class="button stop full" data-action="stop" ${readOnly ? 'disabled' : ''}>${icon('stop',16)}Stop and save</button>
          <p class="fine">Simulated drive. Actual background GPS runs in the native iPhone app.</p>
        </section>` : `
        <section class="card start-card" aria-labelledby="start-title">
          <div class="card-title"><span class="card-icon">${icon('navigation', 22)}</span><div><h2 class="hero" id="start-title">Ready for your next trip</h2><p class="description">Start before you drive. Save every mile.</p></div></div>
          ${segments(['Business', 'Personal'], category, 'category')}
          <label class="form-field"><span class="field-label">Purpose or destination <span class="muted">Optional</span></span><input class="input" id="purpose" aria-label="Purpose or destination" placeholder="e.g. Client visit" maxlength="250" value="${esc(purpose)}"></label>
          <button class="button full" data-action="start" ${readOnly ? 'disabled' : ''}>${icon('play', 16)}Start trip</button>
          <p class="fine">This preview uses simulated GPS. Start and stop each trip manually.</p>
        </section>`;
      app.innerHTML = `
        <header class="app-header flex between"><div><h1>Mileage</h1><p class="subtitle">Your miles, in one place.</p></div><button class="icon-button" data-action="settings" aria-label="Settings and export">${icon('settings', 21)}</button></header>
        ${warning}${card}
        <section class="card summary-card" aria-label="Monthly summary">
          <div class="flex between"><p class="month">${month.toLocaleDateString(undefined, {month: 'long', year: 'numeric'})}</p><span class="muted">${icon('chart', 18)}</span></div>
          <div class="stats"><div><p class="stat-value">${monthTrips.filter(t => t.category === 'Business').reduce((sum, t) => sum + miles(t), 0).toFixed(1)}</p><p class="stat-caption">Business miles</p></div><div><p class="stat-value">${monthTrips.length}</p><p class="stat-caption">Completed trips</p></div></div>
          ${monthTrips.some(needsReview) ? '<p class="orange fine">ⓘ Includes trips that need review</p>' : ''}
        </section>
        <section class="stack"><div class="flex between"><h2>Recent trips</h2><button class="button plain" data-action="history">View all</button></div><div class="trip-list">${completed().length ? completed().slice(0, 5).map(row).join('') : empty('Your first mile starts here', 'Start a trip. Your simulated route and miles will appear here.')}</div></section>
        <p class="flex privacy">${icon('shield', 14)}Saved in this browser. No account required.</p>`;
    }
    function renderHistory(warning){app.innerHTML=`<header class="stack history-header"><button class="back" data-action="home">${icon('back',15)}Mileage</button><h1 class="screen-title">Trip history</h1></header>${warning}<input class="input" id="search" type="search" placeholder="Search purpose or notes" aria-label="Search purpose or notes" value="${esc(query)}">${segments(['All','Business','Personal','Review'],filter,'filter')}<div class="trip-list" id="history-list"></div>`;renderHistoryList();}
    function renderHistoryList(){const found=completed().filter(t=>(filter==='All'||t.category===filter||(filter==='Review'&&needsReview(t)))&&`${t.purpose} ${t.notes}`.toLowerCase().includes(query.toLowerCase()));document.getElementById('history-list').innerHTML=found.length?found.map(row).join(''):empty('No trips found','Try another filter or record a simulated trip.');}
    function routeMap(t) {
      const path = `M55 178V100H145${t.issues.length ? 'M185 100H235V45H293' : 'H235V45H293'}`;
      return `<div class="route-map" aria-label="Illustrative simulated route. Missing sections are not connected.">
        <svg viewBox="0 0 350 220" role="img" aria-label="Simulated route illustration">
          <rect class="map-paper" width="350" height="220"/>
          <path class="map-river" d="M0 165Q65 148 92 178T210 193 350 170" fill="none" stroke-width="24"/>
          <g class="map-road" stroke-width="15"><path d="M-10 45H360M-10 100H360M-10 155H360M55-10V230M145-10V230M235-10V230M325-10V230"/></g>
          <g class="map-road-edge" fill="none" stroke-width="1"><path d="M-10 45H360M-10 100H360M-10 155H360M55-10V230M145-10V230M235-10V230M325-10V230"/></g>
          <rect class="map-park" x="157" y="57" width="65" height="32" rx="4"/>
          <g class="map-label" font-family="sans-serif" font-size="8"><text x="166" y="76">DEMO PARK</text><text x="164" y="33">NORTH STREET</text><text x="263" y="143">OAK AVENUE</text></g>
          <path class="map-route-halo" d="${path}" fill="none" stroke-width="8" stroke-linejoin="round"/>
          <path class="map-route" d="${path}" fill="none" stroke-width="3.5" stroke-linejoin="round"/>
          <circle class="map-start" cx="55" cy="178" r="6" stroke-width="3"/><circle class="map-end" cx="293" cy="45" r="6" stroke-width="3"/>
        </svg><span class="map-caption">Simulated route · illustrative map</span></div>`;
    }
    function renderDetail(warning){
      const t=trips.find(t=>t.id===selectedId);if(!t){go('home');return;}
      app.innerHTML=`<header class="flex between"><button class="back" data-action="history">${icon('back',15)}Trips</button><h1 class="detail-title">Trip details</h1><span class="header-spacer" aria-hidden="true"></span></header>${warning}${t.gpsMiles>0?routeMap(t):empty('No route recorded','This simulated trip ended before the first sample.')}<section class="card"><div class="detail-number">${miles(t).toFixed(2)} <small>miles</small></div><p class="flex green small-text">${icon(t.category==='Business'?'briefcase':'car',17)}${t.category}</p><h3>${esc(t.purpose||'No purpose added')}</h3><dl class="meta"><div><dt>Started</dt><dd>${esc(formatDate(t.startedAt,true))}</dd></div><div><dt>Ended</dt><dd>${esc(formatDate(t.endedAt,true))}</dd></div><div><dt>Data source</dt><dd>Simulated preview</dd></div>${t.adjustedMiles!=null?`<div><dt>Simulated GPS miles</dt><dd>${t.gpsMiles.toFixed(2)}</dd></div>`:''}</dl>${t.adjustedMiles!=null?`<p class="description">Correction: ${esc(t.adjustmentReason)}</p>`:''}${t.notes?`<p class="description preserved-lines">${esc(t.notes)}</p>`:''}</section>${t.issues.length?`<section class="card"><h3 class="${needsReview(t)?'orange':'green'}">${needsReview(t)?'Review this trip':'Reviewed trip'}</h3><p class="description">Missing sections are excluded from mileage. Use a verified full-trip total when correcting a trip.</p>${t.issues.map(issue=>`<p class="orange small-text">${esc(issue)}</p>`).join('')}</section>`:''}<button class="button full" data-action="edit" ${readOnly?'disabled':''}>Edit details or correct mileage</button><button class="button plain danger-text" data-action="delete" ${readOnly?'disabled':''}>Delete trip</button>`;
    }
    function openSheet(title,body){const trigger=document.activeElement;sheetOpener={element:trigger,action:trigger?.dataset?.action,id:trigger?.dataset?.id};sheet.innerHTML=`<div class="sheet-inner"><div class="sheet-header"><h2 id="sheet-title">${title}</h2><button class="close" data-action="close" aria-label="Close dialog">×</button></div>${body}</div>`;sheet.showModal();syncAppearanceControls();}
    function settings(){openSheet('Settings & export',`<section class="stack"><p class="section-label">Appearance</p><label class="form-field">Color theme<select class="input" data-appearance-select aria-label="Color theme"><option value="system">System</option><option value="light">Light</option><option value="dark">Dark</option></select></label><p class="description">System follows your device. Your preference is saved in this browser.</p></section><p class="section-label">Your preview records</p><div class="stack compact-stack"><button class="export-row" data-action="csv" ${completed().length?'':'disabled'}>${icon('export',18)}Export completed trips as CSV</button><button class="export-row" data-action="backup">${icon('shield',18)}Export preview backup (JSON)</button></div><p class="description">All exported records are labeled as simulated preview data. This preview backup is separate from native iPhone records.</p><p class="section-label">How this preview works</p><p class="description">No location permission is needed. A simulated drive runs at 10× speed, adding about 0.08 miles per second. Reloading interrupts the simulation; tap Resume to continue.</p><p class="section-label">The native iPhone app</p><p class="description">Actual GPS, Apple Maps, background recording, and iPhone location permissions require the native app. Open Mileage.xcodeproj with Xcode to run it in Simulator or install it on your iPhone.</p><p class="section-label">Privacy</p><p class="description">Preview records stay in this browser unless you export them. Clearing browser storage removes them. Preview changes do not sync to your iPhone.</p><button class="button secondary full" data-action="samples" ${readOnly?'disabled':''}>Load sample trips</button><p class="muted fine">0.1.0 · Personal beta · Browser preview</p>`);}
    function edit(){const t=trips.find(t=>t.id===selectedId);openSheet('Edit trip',`<form id="edit-form" class="stack"><label class="form-field">Category<select class="input" name="category"><option ${t.category==='Business'?'selected':''}>Business</option><option ${t.category==='Personal'?'selected':''}>Personal</option></select></label><label class="form-field">Purpose<input class="input" name="purpose" maxlength="250" value="${esc(t.purpose)}"></label><label class="form-field">Notes<textarea class="input" name="notes" maxlength="4000">${esc(t.notes)}</textarea></label><label class="checkbox"><input type="checkbox" id="use-correction" name="correction" ${t.adjustedMiles!=null?'checked':''}>Use a verified mileage correction</label><fieldset class="stack" id="correction-fields" ${t.adjustedMiles!=null?'':'hidden disabled'}><label class="form-field">Total trip miles<input class="input" name="adjustedMiles" inputmode="decimal" type="number" min="0" step="any" value="${t.adjustedMiles??''}"></label><label class="form-field">Reason / source (required)<input class="input" name="reason" maxlength="1000" value="${esc(t.adjustmentReason)}"></label><p class="description">The original simulated measurement is kept. Enter the full trip total.</p></fieldset>${t.issues.length?`<label class="checkbox"><input type="checkbox" name="reviewed" ${t.reviewed?'checked':''}>I reviewed the route and mileage</label>`:''}<p class="orange" id="edit-error" role="alert" hidden></p><button class="button full" type="submit">Save changes</button></form>`);}
    function confirmDialog(title,description,label,action,danger=false){openSheet(title,`<p class="description">${description}</p><button class="button ${danger?'danger':'stop'} full" data-action="${action}">${label}</button><button class="button secondary full" data-action="close">Cancel</button>`);}
    function download(name,content,type){try{const url=URL.createObjectURL(new Blob([content],{type}));const a=document.createElement('a');a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);toast('Preview export downloaded');}catch(error){toast('Could not create the preview export');}}
    function csvCell(value){const text=String(value??''),trimmed=text.trim();const safe=/^[=+\-@]/.test(trimmed)&&!(trimmed!==''&&Number.isFinite(Number(trimmed)))?"'"+text:text;return '"'+safe.replaceAll('"','""')+'"';}
    function exportCSV(){const rows=[['Trip ID','Started (UTC)','Ended (UTC)','Category','Purpose','Miles','GPS miles','Adjusted miles','Adjustment reason','Notes','Review status','Recording issues','Data source']];[...completed()].reverse().forEach(t=>rows.push([t.id,t.startedAt,t.endedAt,t.category,t.purpose,miles(t).toFixed(3),t.gpsMiles.toFixed(3),t.adjustedMiles?.toFixed(3)??'',t.adjustmentReason,t.notes,needsReview(t)?'Needs review':t.reviewed?'Reviewed':'No issues flagged',t.issues.join('; '),'SIMULATED BROWSER PREVIEW']));download('Mileage-preview-trips.csv',rows.map(row=>row.map(csvCell).join(',')).join('\r\n')+'\r\n','text/csv;charset=utf-8');}
    function makeTrip(cat,p,startedAt=new Date().toISOString()){return {id:crypto.randomUUID(),startedAt,endedAt:null,category:cat,purpose:p,notes:'',gpsMiles:0,adjustedMiles:null,adjustmentReason:'',issues:[],reviewed:false,demoSeconds:0,interrupted:false};}
    function loadSamples(){
      if(readOnly){toast('Preview storage is unavailable');return;}
      if(trips.some(t=>t.sample)){toast('Sample trips are already loaded');return;}
      const examples=[['Business','Client visit',12.84,32,false],['Personal','Grocery run',4.26,14,false],['Business','Office meeting',8.72,26,true]];
      const samples=examples.map(([cat,p,total,minutes,gap],i)=>{const start=new Date();start.setDate(Math.max(1,start.getDate()-i));start.setHours(9+i*2,10,0,0);const t=makeTrip(cat,p,start.toISOString());t.endedAt=new Date(start.getTime()+minutes*60000).toISOString();t.gpsMiles=total;t.demoSeconds=minutes*60;t.sample=true;if(gap)t.issues=['GPS signal gap (simulated)'];return t;});
      if(commit([...trips,...samples])){if(sheet.open)sheet.close();render();toast('Three simulated sample trips added');}
    }
    document.addEventListener('input',event=>{if(event.target.id==='purpose')purpose=event.target.value;if(event.target.id==='search'){query=event.target.value;renderHistoryList();}});
    document.addEventListener('change', event => {
      if (event.target.matches('[data-appearance-select]')) setAppearance(event.target.value);
      if (event.target.id === 'use-correction') {
        const fields = document.getElementById('correction-fields');
        fields.hidden = !event.target.checked;
        fields.disabled = !event.target.checked;
      }
    });
    document.addEventListener('submit',event=>{
      if(event.target.id!=='edit-form')return;event.preventDefault();const data=new FormData(event.target);const t=trips.find(t=>t.id===selectedId);const correction=data.has('correction'),input=String(data.get('adjustedMiles')).trim(),reason=String(data.get('reason')).trim();
      if(correction&&(input===''||!Number.isFinite(Number(input))||Number(input)<0||!reason)){const error=document.getElementById('edit-error');error.hidden=false;error.textContent='Enter valid miles and explain the source of your correction.';return;}
      const next={...t,category:data.get('category'),purpose:String(data.get('purpose')).trim(),notes:String(data.get('notes')).trim(),adjustedMiles:correction?Number(input):null,adjustmentReason:correction?reason:'',reviewed:data.has('reviewed')};
      if(commit(trips.map(t=>t.id===next.id?next:t))){sheet.close();render();toast('Trip updated');}
    });
    document.addEventListener('click',event=>{
      const button=event.target.closest('[data-action]');if(!button||button.disabled)return;
      const action=button.dataset.action;
      if(action==='home')go('home');
      else if(action==='history')go('history');
      else if(action==='detail')go('detail',button.dataset.id);
      else if(action==='category'){category=button.dataset.value;render();app.querySelector('[data-action="category"][aria-pressed="true"]')?.focus({preventScroll:true});}
      else if(action==='filter'){filter=button.dataset.value;render();app.querySelector('[data-action="filter"][aria-pressed="true"]')?.focus({preventScroll:true});}
      else if(action==='settings')settings();
      else if(action==='close')sheet.close();
      else if(action==='start'){if(!active()&&commit([makeTrip(category,purpose.trim()),...trips])){purpose='';render();toast('Simulated drive started');}}
      else if(action==='stop')confirmDialog('Finish this trip?','This ends the simulated drive and saves it in your preview history.','Stop and save trip','confirm-stop');
      else if(action==='confirm-stop'){const t=active();if(!t)return;const next={...t,endedAt:new Date().toISOString()};if(t.gpsMiles===0)next.issues=[...t.issues,'Not enough simulated points to measure the trip'];if(commit(trips.map(t=>t.id===next.id?next:t))){sheet.close();render();toast('Trip saved to history');}}
      else if(action==='resume'){const t=active();if(t&&commit(trips.map(item=>item.id===t.id?{...t,interrupted:false}:item))){render();toast('Simulation resumed');}}
      else if(action==='edit')edit();
      else if(action==='delete')confirmDialog('Delete this trip?','This permanently removes this trip from your browser preview.','Delete trip','confirm-delete',true);
      else if(action==='confirm-delete'){if(commit(trips.filter(t=>t.id!==selectedId))){sheet.close();go('history');toast('Trip deleted');}}
      else if(action==='samples')loadSamples();
      else if(action==='reset')confirmDialog('Reset the preview?','This removes all simulated trips and any active simulation from this browser.','Reset preview','confirm-reset',true);
      else if(action==='confirm-reset'){if(commit([])){sheet.close();category='Business';purpose='';filter='All';query='';go('home');toast('Preview reset');}}
      else if(action==='csv')exportCSV();
      else if(action==='backup')download('Mileage-preview-backup.json',JSON.stringify({version:1,source:'simulated-browser-preview',exportedAt:new Date().toISOString(),trips},null,2),'application/json');
    });
    setInterval(()=>{
      const t=active();if(!t||t.interrupted||readOnly||document.hidden)return;
      const next={...t,gpsMiles:t.gpsMiles+1/12,demoSeconds:(t.demoSeconds||0)+10};
      if(commit(trips.map(t=>t.id===next.id?next:t))&&view==='home'){
        const live=document.getElementById('live-miles'),elapsed=document.getElementById('elapsed');if(live)live.textContent=next.gpsMiles.toFixed(2);if(elapsed)elapsed.textContent=time(next.demoSeconds);
      }
    },1000);
    render();
