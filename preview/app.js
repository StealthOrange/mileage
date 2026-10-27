'use strict';
// This browser UI demonstrates the native app. It never requests or records real GPS.
const STORAGE_KEY = 'mileage-browser-preview-v1';
const PREFERENCES_KEY = 'mileage-preview-preferences-v1';
const APPEARANCE_KEY = document.documentElement.dataset.appearanceKey;
const app = document.getElementById('app');
const navigation = document.getElementById('navigation');
const sheet = document.getElementById('sheet');
const screen = document.getElementById('screen');
const esc = value => String(value ?? '').replace(/[&<>"']/g, char => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
const icons = {
  home:'<path d="m3 10 9-8 9 8v11h-6v-7H9v7H3V10Z"/>',
  trips:'<path d="M8 5h13M8 12h13M8 19h13M3 5h.01M3 12h.01M3 19h.01"/>',
  reports:'<path d="M4 21V11m8 10V3m8 18V8M2 21h20"/>',
  settings:'<path d="m9 3-1 3-3 1v4l-2 1 2 2v3l3 1 1 3h6l1-3 3-1v-3l2-2-2-1V7l-3-1-1-3H9Z"/><circle cx="12" cy="12" r="3"/>',
  target:'<circle cx="12" cy="12" r="7"/><circle cx="12" cy="12" r="3"/><path d="M12 1v4m0 14v4M1 12h4m14 0h4"/>',
  location:'<path d="m3 10 18-7-7 18-3-8-8-3Z"/>',
  pin:'<path d="M19 10c0 6-7 12-7 12S5 16 5 10a7 7 0 0 1 14 0Z"/><circle cx="12" cy="10" r="2.5"/>',
  play:'<path d="m7 4 14 8-14 8V4Z" fill="currentColor" stroke="none"/>',
  pause:'<rect x="5" y="4" width="5" height="16" rx="1.5" fill="currentColor" stroke="none"/><rect x="14" y="4" width="5" height="16" rx="1.5" fill="currentColor" stroke="none"/>',
  stop:'<rect x="4" y="4" width="16" height="16" rx="2" fill="currentColor" stroke="none"/>',
  chevron:'<path d="m9 5 7 7-7 7"/>',down:'<path d="m5 9 7 7 7-7"/>',back:'<path d="m15 5-7 7 7 7"/>',
  search:'<circle cx="10.5" cy="10.5" r="7.5"/><path d="m16 16 6 6"/>',plus:'<path d="M12 3v18M3 12h18"/>',
  calendar:'<rect x="3" y="5" width="18" height="17" rx="3"/><path d="M3 10h18M7 2v6m10-6v6"/>',
  briefcase:'<rect x="3" y="7" width="18" height="14" rx="3"/><path d="M8 7V4h8v3M3 12a22 22 0 0 0 18 0M12 11v4"/>',
  car:'<path d="m5 9 2-5h10l2 5M3 10h18v8H3v-8Zm2 8v3m14-3v3M6 13h2m8 0h2"/>',
  export:'<path d="M5 10v11h14V10M12 16V2m-4 4 4-4 4 4"/>',
  document:'<path d="M5 2h9l5 5v15H5V2Z"/><path d="M14 2v6h5M8 12h8m-8 4h8"/>',
  cloud:'<path d="M7 19H5a4 4 0 0 1-1-8 8 8 0 0 1 15-2 5 5 0 0 1 0 10h-2M12 12v10m-3-7 3-3 3 3"/>',
  sun:'<circle cx="12" cy="12" r="4"/><path d="M12 1v3m0 16v3M1 12h3m16 0h3M4 4l2 2m12 12 2 2M4 20l2-2M18 6l2-2"/>',
  ruler:'<path d="m3 16 13-13 5 5L8 21l-5-5ZM12 7l3 3m-7 1 3 3m-7 1 3 3"/>',
  shield:'<path d="m12 2 8 3v7c0 5-8 10-8 10S4 17 4 12V5l8-3Z"/><path d="m8 12 3 3 5-6"/>',
  more:'<circle cx="4" cy="12" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="20" cy="12" r="1"/>'
};
const icon = (name, size=22) => `<svg width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${icons[name] || icons.target}</svg>`;
let trips = [], storageError = '', readOnly = false;
let preferences = {profileName:'', vehicleName:'My vehicle', defaultCategory:'Business'};
let view = 'home', selectedId = null, filter = 'All', query = '', showSearch = false;
let selectedMonth = monthKey(new Date()), reportFormat = 'PDF', detailDraft = null;
let appearance = document.documentElement.dataset.theme || 'system', toastTimer, sheetOpener;
try {
  const raw = localStorage.getItem(STORAGE_KEY);
  if (raw) {
    const saved = JSON.parse(raw);
    if (saved.version !== 1 || !Array.isArray(saved.trips) || !saved.trips.every(t => t && typeof t.id === 'string' && ['Business','Personal'].includes(t.category) && Number.isFinite(t.gpsMiles) && Array.isArray(t.issues) && Number.isFinite(Date.parse(t.startedAt)))) throw Error('Invalid preview records');
    trips = saved.trips;
    trips.filter(t => !t.endedAt).forEach(t => {
      t.interrupted = true;
      if (!t.issues.includes('Preview reloaded during trip')) t.issues.push('Preview reloaded during trip');
      t.reviewed = false;
    });
  }
} catch (_) { readOnly = true; storageError = 'Saved preview records could not be opened. They have been kept. Export remains available.'; }
try {
  const saved = JSON.parse(localStorage.getItem(PREFERENCES_KEY) || 'null');
  if (saved && typeof saved === 'object') {
    if (typeof saved.profileName === 'string') preferences.profileName = saved.profileName.slice(0,80);
    if (typeof saved.vehicleName === 'string') preferences.vehicleName = saved.vehicleName.slice(0,80);
    if (['Business','Personal'].includes(saved.defaultCategory)) preferences.defaultCategory = saved.defaultCategory;
  }
} catch (_) { /* Invalid preferences never replace trip records. */ }
const active = () => trips.find(t => !t.endedAt);
const completed = () => trips.filter(t => t.endedAt).sort((a,b) => Date.parse(b.startedAt)-Date.parse(a.startedAt));
const miles = trip => trip.adjustedMiles ?? trip.gpsMiles;
const needsReview = trip => trip.issues.length > 0 && !trip.reviewed;
const titleFor = trip => trip.routeTitle || trip.purpose || `${trip.category} drive`;
const timeOf = date => new Date(date).toLocaleTimeString(undefined,{hour:'numeric',minute:'2-digit'});
const timeRange = trip => `${timeOf(trip.startedAt)} – ${timeOf(trip.endedAt || new Date())}`;
const elapsed = seconds => [Math.floor(seconds/3600),Math.floor(seconds/60)%60,Math.floor(seconds)%60].map(value=>String(value).padStart(2,'0')).join(':');
function monthKey(date) { return `${date.getFullYear()}-${String(date.getMonth()+1).padStart(2,'0')}`; }
function dateKey(value) { const date=new Date(value); return `${date.getFullYear()}-${date.getMonth()}-${date.getDate()}`; }
function monthLabel(value) { const [year,month]=value.split('-').map(Number);return new Date(year,month-1,1).toLocaleDateString(undefined,{month:'long',year:'numeric'}); }
function durationMinutes(trip) { return Math.max(0,Math.round(((trip.demoSeconds || 0)*1000 || (Date.parse(trip.endedAt)-Date.parse(trip.startedAt)))/60000)); }
function dayLabel(value) {
  const date = new Date(value), now = new Date(), yesterday = new Date(); yesterday.setDate(now.getDate()-1);
  if (dateKey(date)===dateKey(now)) return 'Today';
  if (dateKey(date)===dateKey(yesterday)) return 'Yesterday';
  return date.toLocaleDateString(undefined,{month:'short',day:'numeric'});
}
function commit(next) {
  if (readOnly) return false;
  try {
    localStorage.setItem(STORAGE_KEY,JSON.stringify({version:1,source:'simulated-browser-preview',trips:next}));
    trips=next; storageError=''; return true;
  } catch (_) { readOnly=true;storageError='This browser could not save your preview. Recording has stopped. Export your records before continuing.';render();return false; }
}
function savePreferences(next) {
  try { localStorage.setItem(PREFERENCES_KEY,JSON.stringify(next));preferences=next;return true; }
  catch (_) { toast('This browser could not save your preferences');return false; }
}
function syncAppearance() {
  document.querySelectorAll('[data-appearance-select]').forEach(select=>select.value=appearance);
  document.querySelectorAll('[data-action="appearance"]').forEach(button=>{
    const selected=button.dataset.value===appearance;button.classList.toggle('selected',selected);button.setAttribute('aria-pressed',String(selected));
  });
  document.querySelector('meta[name="theme-color"]').content=getComputedStyle(document.documentElement).getPropertyValue('--color-background').trim();
}
function setAppearance(value) {
  if (!['system','light','dark'].includes(value)) return;
  appearance=value;document.documentElement.dataset.theme=value;
  try {localStorage.setItem(APPEARANCE_KEY,value);} catch (_) {}
  syncAppearance();
}
window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change',syncAppearance);
function toast(message) { const node=document.getElementById('toast');node.textContent=message;node.hidden=false;clearTimeout(toastTimer);toastTimer=setTimeout(()=>node.hidden=true,3500); }
function go(next,id=null) {
  view=next;selectedId=id;detailDraft=null;render();screen.scrollTop=0;
  const heading=app.querySelector('h1');if(heading){heading.tabIndex=-1;heading.focus({preventScroll:true});}
}
function renderNavigation() {
  navigation.hidden=view==='active'||view==='detail';
  const current=view==='history'?'trips':view;
  navigation.innerHTML=[['home','Home'],['trips','Trips'],['reports','Reports'],['settings','Settings']].map(([key,title])=>`<button data-action="navigate" data-view="${key}" class="${current===key?'active':''}" aria-current="${current===key?'page':'false'}">${icon(key,24)}<span>${title}</span></button>`).join('');
}
function render() {
  renderNavigation();
  if (view==='home') renderHome();
  else if (view==='active') renderActive();
  else if (view==='trips'||view==='history') renderTrips();
  else if (view==='detail') renderDetail();
  else if (view==='reports') renderReports();
  else renderSettings();
  if(storageError)app.insertAdjacentHTML('afterbegin',`<p role="alert" class="issue storage-warning">${esc(storageError)}</p>`);
  syncAppearance();
}
function point(angle,radius=140,cx=160,cy=160) { const radians=angle*Math.PI/180;return{x:cx+Math.cos(radians)*radius,y:cy+Math.sin(radians)*radius}; }
function arc(start,end,radius=140,cx=160,cy=160) {const a=point(start,radius,cx,cy),b=point(end,radius,cx,cy);return`M${a.x.toFixed(3)} ${a.y.toFixed(3)} A${radius} ${radius} 0 ${end-start>180?1:0} 1 ${b.x.toFixed(3)} ${b.y.toFixed(3)}`;}
function gauge({value=0,label='This week',maximum=200,days=null,timer=null,report=false}={}) {
  const start=report?180:135,sweep=report?180:270,cy=report?170:160,radius=report?139:138;
  const fraction=Math.max(0,Math.min(1,value/maximum)),end=start+sweep*fraction;
  const tickCount=report?60:72;
  const ticks=Array.from({length:tickCount+1},(_,i)=>{
    const angle=start+sweep*i/tickCount,major=i%(report?15:18)===0,a=point(angle,radius+7,160,cy),b=point(angle,radius+(major?15:12),160,cy);
    return`<line x1="${a.x}" y1="${a.y}" x2="${b.x}" y2="${b.y}" class="dial-tick ${major?'major':''}" stroke-width="${major?1.6:.75}"/>`;
  }).join('');
  const endPoint=point(end,radius-7,160,cy);
  const bars=days?days.map((total,i)=>{const height=total?Math.max(5,Math.min(29,total/Math.max(...days,1)*29)):10;return`<rect class="week-bar ${total?'recorded':''}" x="${111+i*16}" y="${257-height}" width="4" height="${height}" rx="2"/><text x="${113+i*16}" y="273" class="week-day" text-anchor="middle">${['M','T','W','T','F','S','S'][i]}</text>`;}).join(''):'';
  const axis=report?`<text x="160" y="64" text-anchor="middle" class="dial-axis">${maximum/2}</text><text x="16" y="186" text-anchor="middle" class="dial-axis">0</text><text x="304" y="186" text-anchor="middle" class="dial-axis">${maximum}</text>`:timer==null?'<text x="160" y="62" text-anchor="middle" class="dial-axis">100</text><text x="59" y="155" text-anchor="middle" class="dial-axis">50</text><text x="262" y="155" text-anchor="middle" class="dial-axis">150</text><text x="76" y="260" text-anchor="middle" class="dial-axis">0</text><text x="249" y="260" text-anchor="middle" class="dial-axis">200</text>':'';
  return`<svg viewBox="0 0 320 ${report?199:298}" role="img" aria-label="${esc(label)}: ${value.toFixed(1)} miles${timer!=null?', '+elapsed(timer)+' simulated elapsed':''}">
    <path d="${arc(start,start+sweep,radius+18,160,cy)}" class="dial-outline" stroke-width="1"/>
    ${ticks}<path d="${arc(start,start+sweep,radius-7,160,cy)}" class="dial-track"/>
    ${fraction>0?`<path d="${arc(start,end,radius-7,160,cy)}" class="dial-progress"/><circle class="dial-end" cx="${endPoint.x}" cy="${endPoint.y}" r="4.5"/>`:''}
    ${axis}<text x="160" y="${report?98:111}" class="dial-label" text-anchor="middle">${esc(label)}</text>
    <text x="160" y="${report?148:168}" class="dial-number" text-anchor="middle">${value.toFixed(1)}</text>
    <text x="160" y="${report?175:194}" class="dial-unit" text-anchor="middle">mi</text>
    ${bars}${timer!=null?`<text x="160" y="229" class="dial-timer" text-anchor="middle">${elapsed(timer)}</text><text x="160" y="252" class="dial-caption" text-anchor="middle">Simulated GPS tracking</text>`:''}</svg>`;
}
function mapMarkup(options={}) { return window.mileageMapMarkup(options); }
function routeMini(business=true) {return`<span class="route-mini"><svg viewBox="0 0 26 38" fill="none" aria-hidden="true"><path d="M5 7v9c0 9 5 13 16 14" stroke="currentColor" stroke-width="1.4"/><circle cx="5" cy="6" r="3.5" fill="var(--bg)" stroke="var(--text)" stroke-width="1.8"/><circle cx="21" cy="30" r="3.5" fill="var(--bg)" stroke="var(--text)" stroke-width="1.8"/></svg></span>`;}
function tripRow(trip,includeDay=false) {
  return`<button class="trip-row" data-action="detail" data-id="${esc(trip.id)}" aria-label="${esc(titleFor(trip))}, ${miles(trip).toFixed(1)} miles, ${trip.category}${needsReview(trip)?', needs review':''}">
    <span class="trip-route-icon ${trip.category==='Business'?'business':''}">${routeMini()}</span>
    <span class="trip-copy"><span class="trip-title">${esc(titleFor(trip))}</span><span class="trip-date">${includeDay?esc(dayLabel(trip.startedAt))+', ':''}${esc(timeRange(trip))}</span>${needsReview(trip)?'<span class="review-label">Needs review</span>':''}</span>
    <span class="trip-distance">${miles(trip).toFixed(1)} mi</span><span class="category-chip ${trip.category==='Business'?'business':''}">${trip.category}</span><span class="trip-chevron">${icon('chevron',12)}</span></button>`;
}
function empty(title,description) {return`<div class="preview-empty">${icon('location',26)}<h3>${title}</h3><p>${description}</p></div>`;}
function weekTrips() {const monday=new Date();monday.setHours(0,0,0,0);monday.setDate(monday.getDate()-(monday.getDay()+6)%7);const end=new Date(monday);end.setDate(end.getDate()+7);return completed().filter(trip=>Date.parse(trip.startedAt)>=monday.getTime()&&Date.parse(trip.startedAt)<end.getTime());}
function renderHome() {
  const weekly=weekTrips(),total=weekly.reduce((sum,trip)=>sum+miles(trip),0),days=Array(7).fill(0);
  weekly.forEach(trip=>days[(new Date(trip.startedAt).getDay()+6)%7]+=miles(trip));
  const current=active(),mapTrip=completed().find(trip=>trip.gpsMiles>0);
  app.innerHTML=`<header class="app-header"><h1>Mileage</h1><div class="header-actions"><button class="icon-button outlined" data-action="navigate" data-view="settings" aria-label="Settings">${icon('target',17)}</button><span class="status-pill"><span class="status-dot"></span>Manual tracking</span></div></header>
    <div class="instrument">${gauge({value:total,days})}</div>
    <div class="dashboard-map">${mapMarkup({showRoute:!!mapTrip})}<span class="location-pill">${icon('location',16)}Houston, TX</span></div>
    <div class="home-start"><button class="button" data-action="${current?'active':'start'}" ${readOnly&&!current?'disabled':''}>${icon('play',20)}${current?'View active drive':'Start drive'}</button></div>
    <section class="home-recent"><div class="section-head"><h2>Recent trips</h2><button class="text-button" data-action="navigate" data-view="trips">See all${icon('chevron',14)}</button></div><div class="trip-list">${completed().length?completed().slice(0,2).map(trip=>tripRow(trip,true)).join(''):empty('Your first mile starts here','Start a simulated drive or load the sample trips.')}</div></section>
    <p class="preview-note">Illustrative Houston map · Simulated GPS<br>Real background tracking is available in the native iPhone app.</p>`;
}
function renderActive() {
  const trip=active();if(!trip){go('home');return;}
  const paused=trip.interrupted||trip.paused;
  app.innerHTML=`<header class="app-header active-header"><button class="icon-button" data-action="navigate" data-view="home" aria-label="Back to home">${icon('back',20)}</button><h1>Drive in progress</h1><span class="status-pill">${icon('location',12)}<span class="status-dot"></span>${paused?'Paused':'Recording'}</span></header>
    <div class="instrument" id="live-instrument">${gauge({value:trip.gpsMiles,label:'Distance',maximum:20,timer:trip.demoSeconds||0})}</div>
    <div class="active-map"><div id="live-route">${mapMarkup({showRoute:trip.gpsMiles>0,progress:Math.min(1,trip.gpsMiles/18.7)})}</div><span class="location-pill">${icon('location',16)}Houston, TX</span></div>
    <div class="active-controls">${segments(['Business','Personal'],trip.category,'active-category','Trip type')}<div class="active-buttons"><button class="button secondary" data-action="${paused?'resume':'pause'}" ${readOnly?'disabled':''}>${icon(paused?'play':'pause',19)}${paused?'Resume':'Pause'}</button><button class="button" data-action="stop" ${readOnly?'disabled':''}>${icon('stop',19)}End drive</button></div><p class="recording-note">${trip.interrupted?'Reload interrupted this drive. Resume to continue.':'Preview simulation · No real location is recorded.'}</p></div>`;
}
function segments(values,selected,action,label='Filter trips') {return`<div class="segment" role="group" aria-label="${label}">${values.map(value=>`<button type="button" data-action="${action}" data-value="${value}" aria-pressed="${selected===value}" class="${selected===value?'selected':''}">${value}</button>`).join('')}</div>`;}
function monthSelect(compact=false) {
  const values=[...new Set([monthKey(new Date()),selectedMonth,...completed().map(trip=>monthKey(new Date(trip.startedAt)))])].sort().reverse();
  return`<label class="month-selector ${compact?'compact':''}">${compact?'':icon('calendar',21)}<span class="sr-only">Month</span><select data-month-select aria-label="Month">${values.map(value=>`<option value="${value}" ${selectedMonth===value?'selected':''}>${esc(monthLabel(value))}</option>`).join('')}</select>${icon('down',14)}</label>`;
}
function monthTrips() {return completed().filter(trip=>monthKey(new Date(trip.startedAt))===selectedMonth);}
function filteredTrips() {return monthTrips().filter(trip=>(filter==='All'||trip.category===filter||(filter==='Review'&&needsReview(trip)))&&`${titleFor(trip)} ${trip.purpose} ${trip.notes}`.toLowerCase().includes(query.toLowerCase()));}
function renderTrips() {
  const found=filteredTrips();
  app.innerHTML=`<header class="page-header"><h1>Trips</h1><button class="icon-button" data-action="search" aria-label="Search trips">${icon('search',23)}</button></header><div class="page-content">${segments(['All','Business','Personal'],filter,'filter')}${showSearch?`<label class="search-field">${icon('search',18)}<input id="search" type="search" placeholder="Search route, purpose, or notes" aria-label="Search trips" value="${esc(query)}"></label>`:''}${monthSelect()}<div class="month-summary"><div><p class="month-total" id="trip-total">${found.reduce((sum,trip)=>sum+miles(trip),0).toFixed(1)}<small>mi</small></p><p class="month-count" id="trip-count">${found.length} ${found.length===1?'trip':'trips'}</p></div><button class="button small-button" data-action="add-trip" ${readOnly?'disabled':''}>${icon('plus',18)}Add trip</button></div><div id="history-list">${groupedHistory(found)}</div></div>`;
}
function groupedHistory(found) {
  if(!found.length)return empty('No trips found','Start a drive, add a verified trip, or try another month.');
  const groups=new Map();found.forEach(trip=>{const key=dateKey(trip.startedAt);if(!groups.has(key))groups.set(key,[]);groups.get(key).push(trip);});
  return[...groups.values()].map(group=>`<section class="date-group"><div class="date-heading"><h2>${esc(dayLabel(group[0].startedAt))}</h2><span>${group.length} ${group.length===1?'trip':'trips'}</span></div><div class="trip-list">${group.map(trip=>tripRow(trip)).join('')}</div></section>`).join('<div class="group-spacer"></div>');
}
function updateSearch() {const found=filteredTrips();document.getElementById('history-list').innerHTML=groupedHistory(found);document.getElementById('trip-total').innerHTML=`${found.reduce((sum,trip)=>sum+miles(trip),0).toFixed(1)}<small>mi</small>`;document.getElementById('trip-count').textContent=`${found.length} ${found.length===1?'trip':'trips'}`;}
function renderDetail() {
  const trip=trips.find(item=>item.id===selectedId);if(!trip){go('trips');return;}
  if(!detailDraft)detailDraft={...trip};
  const [from,to]=trip.routeTitle?.split(' → ')||[trip.startLocation||'Drive start',trip.endLocation||'Drive end'];
  const startLabel=trip.startLocation||from,endLabel=trip.endLocation||to;
  app.innerHTML=`<div class="detail-topline"><button class="back-button" data-action="navigate" data-view="trips">${icon('back',18)}Trips</button><button class="icon-button" data-action="trip-options" aria-label="Trip options">${icon('more',22)}</button></div><h1 class="detail-heading">Trip details</h1><form class="page-content" id="detail-form" novalidate>
    ${trip.gpsMiles>0?`<div class="detail-map">${mapMarkup({showRoute:true,compact:true})}</div>`:empty('No GPS route recorded',trip.manual?'This is a manually entered preview trip.':'This drive ended before a simulated GPS sample.')}
    <div class="detail-stats"><div><strong>${miles(trip).toFixed(1)} mi</strong><span>Distance</span></div><div><strong>${durationMinutes(trip)} min</strong><span>Duration</span></div><div><strong>${new Date(trip.startedAt).toLocaleDateString(undefined,{month:'short',day:'numeric',year:'numeric'})}</strong><span>${esc(timeRange(trip))}</span></div></div>
    <div class="route-stops"><div class="route-stop"><span class="route-node"></span><div class="route-stop-content"><div><strong>${esc(startLabel)}</strong><p>Houston, TX · Illustrative</p></div><time>${esc(timeOf(trip.startedAt))}</time></div></div><div class="route-stop"><span class="route-node end"></span><div class="route-stop-content"><div><strong>${esc(endLabel)}</strong><p>Houston, TX · Illustrative</p></div><time>${esc(timeOf(trip.endedAt))}</time></div></div></div>
    ${segments(['Business','Personal'],detailDraft.category,'detail-category','Trip type')}
    <div class="editor-rows"><div class="editor-row">${icon('target',21)}<label for="detail-purpose">Purpose</label><input class="inline-field" name="purpose" id="detail-purpose" maxlength="250" placeholder="Add purpose" value="${esc(detailDraft.purpose)}">${icon('chevron',12)}</div><div class="editor-row">${icon('car',21)}<label for="detail-vehicle">Vehicle</label><input class="inline-field" name="vehicle" id="detail-vehicle" maxlength="80" value="${esc(detailDraft.vehicle||preferences.vehicleName)}">${icon('chevron',12)}</div><div class="editor-row">${icon('document',21)}<label for="detail-notes">Notes</label><input class="inline-field" name="notes" id="detail-notes" maxlength="4000" placeholder="Add a note" value="${esc(detailDraft.notes)}">${icon('chevron',12)}</div></div>
    ${trip.issues.length?`<div class="issue"><strong>${needsReview(trip)?'Review this trip':'Reviewed trip'}</strong><p>${trip.issues.map(esc).join(' · ')}</p><p>Missing GPS sections are excluded.</p><label class="review-toggle"><input type="checkbox" name="reviewed" ${detailDraft.reviewed?'checked':''}>I reviewed the route and mileage</label></div>`:''}
    ${trip.adjustedMiles!=null?`<p class="description">Original simulated GPS: ${trip.gpsMiles.toFixed(2)} mi<br>Correction: ${esc(trip.adjustmentReason)}</p>`:''}
    <div class="detail-actions"><button class="button full" type="submit" ${readOnly?'disabled':''}>Save changes</button><button class="text-button" type="button" data-action="correct" ${readOnly?'disabled':''}>Correct mileage</button></div></form>`;
}
function renderReports() {
  const records=monthTrips(),business=records.filter(trip=>trip.category==='Business'),personal=records.filter(trip=>trip.category==='Personal');
  const busMiles=business.reduce((sum,trip)=>sum+miles(trip),0),personalMiles=personal.reduce((sum,trip)=>sum+miles(trip),0),total=busMiles+personalMiles;
  const max=Math.max(600,Math.ceil(total/200)*200);
  app.innerHTML=`<header class="page-header"><h1>Reports</h1>${monthSelect(true)}</header><div class="page-content"><div class="report-instrument">${gauge({value:total,label:'Total mileage',maximum:max,report:true})}</div><div class="report-totals"><div class="report-total"><p class="report-label"><span class="legend-dot"></span>Business</p><strong>${busMiles.toFixed(1)}<small>mi</small></strong></div><div class="report-total"><p class="report-label"><span class="legend-dot personal"></span>Personal</p><strong>${personalMiles.toFixed(1)}<small>mi</small></strong></div></div>${reportChart(records)}<div class="chart-legend"><span><i class="legend-dot"></i>Business</span><span><i class="legend-dot personal"></i>Personal</span></div><div class="report-counts">${[['All','Total trips',records.length],['Business','Business trips',business.length],['Personal','Personal trips',personal.length]].map(([category,title,count])=>`<button class="report-count" data-action="report-trips" data-value="${category}"><span class="trip-route-icon ${category==='Business'?'business':''}">${routeMini()}</span><span>${title}</span><strong>${count}</strong>${icon('chevron',13)}</button>`).join('')}</div><button class="button full" data-action="export-report" ${records.length?'':'disabled'}>${icon('document',21)}Export report</button><div class="report-format"><span>Format</span>${segments(['PDF','CSV'],reportFormat,'report-format','Report format')}</div><p class="report-footnote">${reportFormat==='PDF'?'PDF opens your print dialog. Choose Save as PDF.':'CSV downloads the selected month’s completed trips.'} All records are labeled as browser-preview data.</p></div>`;
}
function reportChart(records) {
  const [year,month]=selectedMonth.split('-').map(Number),weekCount=Math.ceil(new Date(year,month,0).getDate()/7),values=Array.from({length:weekCount},()=>({business:0,personal:0}));
  records.forEach(trip=>{const index=Math.floor((new Date(trip.startedAt).getDate()-1)/7);values[index][trip.category.toLowerCase()]+=miles(trip);});
  const maximum=Math.max(50,Math.ceil(Math.max(...values.flatMap(value=>[value.business,value.personal]))/50)*50),height=102,top=12,bottom=top+height;
  const grid=Array.from({length:4},(_,i)=>{const y=top+i*height/3;return`<line class="chart-grid" x1="29" y1="${y}" x2="350" y2="${y}"/><text class="chart-label" x="23" y="${y+4}" text-anchor="end">${Math.round(maximum*(1-i/3))}</text>`;}).join('');
  const slot=320/weekCount;
  const bars=values.map((value,i)=>{const x=29+i*slot+slot/2;return`<rect class="chart-business" x="${x-18}" y="${bottom-value.business/maximum*height}" width="16" height="${value.business/maximum*height}" rx="3"/><rect class="chart-personal" x="${x+3}" y="${bottom-value.personal/maximum*height}" width="16" height="${value.personal/maximum*height}" rx="3"/><text class="chart-label" x="${x}" y="${bottom+17}" text-anchor="middle">Week ${i+1}</text>`;}).join('');
  return`<svg class="report-chart" viewBox="0 0 360 145" role="img" aria-label="Weekly business and personal mileage for ${esc(monthLabel(selectedMonth))}">${grid}${bars}</svg>`;
}
function settingsRow(symbol,title,subtitle,action=null,trailing='') {return`<${action?'button':'div'} class="settings-row" ${action?`data-action="${action}"`:''}>${icon(symbol,22)}<span class="settings-row-copy"><strong>${title}</strong>${subtitle?`<small>${subtitle}</small>`:''}</span>${trailing||(action?icon('chevron',13):'')}</${action?'button':'div'}>`;}
function renderSettings() {
  const initials=preferences.profileName.trim().split(/\s+/).slice(0,2).map(part=>part[0]).join('').toUpperCase()||'Me';
  app.innerHTML=`<header class="page-header"><h1>Settings</h1></header><div class="page-content"><button class="profile-row" data-action="profile"><span class="avatar">${esc(initials)}</span><span class="profile-copy"><strong>${esc(preferences.profileName||'Your profile')}</strong><span>Local profile · No account required</span></span>${icon('chevron',15)}</button>
    <section class="settings-section"><h2>Tracking</h2><div class="settings-group">${settingsRow('target','Drive recording','Manual Start / Stop')}${settingsRow('pin','Location access','Simulated in browser','location-info')}${settingsRow('shield','Background recording','Native iPhone app only','background-info')}</div></section>
    <section class="settings-section"><h2>Preferences</h2><div class="settings-group">${settingsRow('ruler','Units','Miles')}${settingsRow('briefcase','Default trip type',preferences.defaultCategory,'default-category')}<div class="settings-row appearance-row">${icon('sun',22)}<span class="settings-row-copy"><strong>Appearance</strong></span><div class="segment appearance" role="group" aria-label="Color theme">${['system','light','dark'].map(value=>`<button data-action="appearance" data-value="${value}" aria-pressed="${appearance===value}" class="${appearance===value?'selected':''}">${value[0].toUpperCase()+value.slice(1)}</button>`).join('')}</div></div></div></section>
    <section class="settings-section"><h2>Data</h2><div class="settings-group">${settingsRow('export','Export data','','export-options')}${settingsRow('cloud','Local backup','Download a preview JSON backup','backup')}</div></section>
    <div class="settings-group">${settingsRow('car','Manage vehicle',esc(preferences.vehicleName),'vehicle')}</div><p class="settings-note">Records are stored only in this browser. No cloud sync or automatic drive detection is enabled. The native iPhone app provides actual GPS and background recording.</p><div class="settings-footer"><span>Mileage 0.1.0 · Personal beta</span><button class="text-button" data-action="reset">Reset preview data</button></div></div>`;
}
function openSheet(title,body) {
  if(!sheet.open){const trigger=document.activeElement;sheetOpener={element:trigger,action:trigger?.dataset?.action,id:trigger?.dataset?.id};}
  sheet.innerHTML=`<div class="sheet-inner"><div class="sheet-header"><h2 id="sheet-title">${title}</h2><button class="close-button" data-action="close" aria-label="Close dialog">×</button></div>${body}</div>`;
  if(!sheet.open)sheet.showModal();else sheet.querySelector('.close-button')?.focus();syncAppearance();
}
function confirmation(title,description,label,action,danger=false) {openSheet(title,`<p class="description">${description}</p><button class="button full ${danger?'danger':''}" data-action="${action}">${label}</button><button class="button secondary full" data-action="close">Cancel</button>`);}
function correctionSheet() {
  const trip=trips.find(item=>item.id===selectedId);if(!trip)return;
  openSheet('Correct mileage',`<form class="stack" id="correction-form"><p class="description">Original simulated GPS: ${trip.gpsMiles.toFixed(2)} mi. The measurement and route will be preserved.</p><label class="checkbox"><input type="checkbox" name="correction" id="use-correction" ${trip.adjustedMiles!=null?'checked':''}>Use a verified full-trip total</label><fieldset class="stack" id="correction-fields" ${trip.adjustedMiles!=null?'':'hidden disabled'}><label class="form-field">Total trip miles<input class="input" name="adjustedMiles" type="number" min="0" step="any" inputmode="decimal" value="${trip.adjustedMiles??''}"></label><label class="form-field">Reason / source<input class="input" name="reason" maxlength="1000" value="${esc(trip.adjustmentReason)}"></label></fieldset><p class="danger-text small" role="alert" id="form-error" hidden></p><button class="button full" type="submit">Save correction</button></form>`);
}
function localDateTime(date) {const adjusted=new Date(date.getTime()-date.getTimezoneOffset()*60000);return adjusted.toISOString().slice(0,16);}
function addTripSheet() {
  const end=new Date(),start=new Date(end.getTime()-30*60000);
  openSheet('Add trip',`<form class="stack" id="add-trip-form"><p class="description">Enter a full trip total from an odometer or another record. Manual trips have no GPS route.</p><label class="form-field">Start location<input class="input" name="from" required maxlength="120" placeholder="e.g. Downtown"></label><label class="form-field">Destination<input class="input" name="to" required maxlength="120" placeholder="e.g. Energy Corridor"></label><label class="form-field">Category<select class="input" name="category"><option ${preferences.defaultCategory==='Business'?'selected':''}>Business</option><option ${preferences.defaultCategory==='Personal'?'selected':''}>Personal</option></select></label><label class="form-field">Started<input class="input" type="datetime-local" name="startedAt" required value="${localDateTime(start)}"></label><label class="form-field">Ended<input class="input" type="datetime-local" name="endedAt" required value="${localDateTime(end)}"></label><label class="form-field">Total trip miles<input class="input" name="miles" type="number" min="0" step="any" required inputmode="decimal"></label><label class="form-field">Source / reason<input class="input" name="reason" required maxlength="1000" placeholder="e.g. Odometer reading"></label><label class="form-field">Purpose <span class="muted">Optional</span><input class="input" name="purpose" maxlength="250"></label><p class="danger-text small" role="alert" id="form-error" hidden></p><button class="button full" type="submit">Save trip</button></form>`);
}
function makeTrip(category,purpose='',startedAt=new Date().toISOString()) {return{id:crypto.randomUUID(),startedAt,endedAt:null,category,purpose,notes:'',gpsMiles:0,adjustedMiles:null,adjustmentReason:'',issues:[],reviewed:false,demoSeconds:0,interrupted:false,paused:false,vehicle:preferences.vehicleName};}
function startTrip() {if(active()){go('active');return;}if(commit([makeTrip(preferences.defaultCategory),...trips])){go('active');toast('Simulated drive started');}}
function loadSamples() {
  if(readOnly){toast('Preview storage is unavailable');return;}
  if(trips.some(trip=>trip.sampleSet==='obsidian-v1')){toast('Houston sample trips are already loaded');return;}
  const examples=[['Business','Downtown','Energy Corridor',18.7,38,0,8,14,'Client meeting'],['Personal','Heights','Hobby Airport',22.3,39,0,10,3,'Airport pickup'],['Business','The Woodlands','Downtown',26.1,43,1,9,15,'Office visit'],['Personal','Sugar Land','Medical Center',19.6,37,1,13,12,'Appointment'],['Business','Katy','Galleria',41.7,48,1,17,20,'Client visit']];
  const samples=examples.map(([category,from,to,total,minutes,days,hour,minute,purpose])=>{
    const date=new Date();date.setDate(date.getDate()-days);date.setHours(hour,minute,0,0);
    const trip=makeTrip(category,purpose,date.toISOString());
    return{...trip,endedAt:new Date(date.getTime()+minutes*60000).toISOString(),gpsMiles:total,demoSeconds:minutes*60,routeTitle:`${from} → ${to}`,startLocation:from==='Downtown'?'Downtown Houston':from,endLocation:to,sample:true,sampleSet:'obsidian-v1'};
  });
  if(commit([...trips,...samples])){if(sheet.open)sheet.close();render();toast('Five Houston sample trips added. Existing records kept.');}
}
function download(name,content,type) {try{const url=URL.createObjectURL(new Blob([content],{type})),link=document.createElement('a');link.href=url;link.download=name;link.click();setTimeout(()=>URL.revokeObjectURL(url),1000);toast('Preview export downloaded');}catch(_){toast('Could not create the export');}}
function csvCell(value) {const text=String(value??''),trimmed=text.trim();const safe=/^[=+\-@]/.test(trimmed)&&!(trimmed!==''&&Number.isFinite(Number(trimmed)))?"'"+text:text;return'"'+safe.replaceAll('"','""')+'"';}
function exportCSV(records=completed()) {
  const rows=[['Trip ID','Started (UTC)','Ended (UTC)','Category','Route','Purpose','Miles','GPS miles','Adjusted miles','Adjustment reason','Notes','Vehicle','Review status','Recording issues','Data source']];
  [...records].sort((a,b)=>Date.parse(a.startedAt)-Date.parse(b.startedAt)).forEach(trip=>rows.push([trip.id,trip.startedAt,trip.endedAt,trip.category,titleFor(trip),trip.purpose,miles(trip).toFixed(3),trip.gpsMiles.toFixed(3),trip.adjustedMiles?.toFixed(3)??'',trip.adjustmentReason,trip.notes,trip.vehicle||preferences.vehicleName,needsReview(trip)?'Needs review':trip.reviewed?'Reviewed':'No issues flagged',trip.issues.join('; '),trip.manual?'MANUALLY ENTERED BROWSER PREVIEW':'SIMULATED BROWSER PREVIEW']));
  download('Mileage-preview-trips.csv',rows.map(row=>row.map(csvCell).join(',')).join('\r\n')+'\r\n','text/csv;charset=utf-8');
}
function exportBackup() {download('Mileage-preview-backup.json',JSON.stringify({version:1,source:'simulated-browser-preview',exportedAt:new Date().toISOString(),trips},null,2),'application/json');}
function printReport() {
  const records=monthTrips(),business=records.filter(trip=>trip.category==='Business').reduce((sum,trip)=>sum+miles(trip),0),personal=records.filter(trip=>trip.category==='Personal').reduce((sum,trip)=>sum+miles(trip),0);
  document.querySelector('.print-report')?.remove();
  const report=document.createElement('section');report.className='print-report';report.innerHTML=`<h1>Mileage report</h1><h2>${esc(monthLabel(selectedMonth))}</h2><p>Total: ${(business+personal).toFixed(1)} miles · Business: ${business.toFixed(1)} miles · Personal: ${personal.toFixed(1)} miles</p><p>${records.length} completed trips</p><p><strong>Browser preview data. Routes are simulated or manually entered.</strong></p><table><thead><tr><th>Date</th><th>Route / purpose</th><th>Category</th><th>Miles</th><th>Review</th></tr></thead><tbody>${records.map(trip=>`<tr><td>${esc(new Date(trip.startedAt).toLocaleDateString())}</td><td>${esc(titleFor(trip))}</td><td>${trip.category}</td><td>${miles(trip).toFixed(2)}</td><td>${needsReview(trip)?'Needs review':'Reviewed / no issues'}</td></tr>`).join('')}</tbody></table><p><small>Generated ${esc(new Date().toLocaleString())}. No real GPS was collected by this browser preview.</small></p>`;
  document.body.append(report);window.print();
}
function showError(message) {const error=document.getElementById('form-error');error.textContent=message;error.hidden=false;}
sheet.addEventListener('click',event=>{if(event.target!==sheet)return;const rect=sheet.getBoundingClientRect();if(event.clientX<rect.left||event.clientX>rect.right||event.clientY<rect.top||event.clientY>rect.bottom)sheet.close();});
sheet.addEventListener('close',()=>{
  if(sheetOpener?.element?.isConnected)sheetOpener.element.focus({preventScroll:true});
  else {const target=[...document.querySelectorAll('[data-action]')].find(node=>node.dataset.action===sheetOpener?.action&&(!sheetOpener?.id||node.dataset.id===sheetOpener.id));if(target)target.focus({preventScroll:true});else{const heading=app.querySelector('h1');if(heading){heading.tabIndex=-1;heading.focus({preventScroll:true});}}}
  sheetOpener=null;
});
document.addEventListener('input',event=>{
  if(event.target.id==='search'){query=event.target.value;updateSearch();}
  if(view==='detail'&&detailDraft&&['purpose','vehicle','notes'].includes(event.target.name))detailDraft[event.target.name]=event.target.value;
  if(view==='detail'&&detailDraft&&event.target.name==='reviewed')detailDraft.reviewed=event.target.checked;
});
document.addEventListener('change',event=>{
  if(event.target.matches('[data-appearance-select]'))setAppearance(event.target.value);
  if(event.target.matches('[data-month-select]')){selectedMonth=event.target.value;render();app.querySelector('[data-month-select]')?.focus({preventScroll:true});}
  if(event.target.id==='use-correction'){const fields=document.getElementById('correction-fields');fields.hidden=!event.target.checked;fields.disabled=!event.target.checked;}
});
document.addEventListener('submit',event=>{
  const form=event.target,data=new FormData(form);event.preventDefault();
  if(form.id==='detail-form'){
    const trip=trips.find(item=>item.id===selectedId);if(!trip||trip.endedAt==null)return;
    const updated={...trip,...detailDraft,purpose:String(data.get('purpose')||'').trim(),vehicle:String(data.get('vehicle')||'').trim(),notes:String(data.get('notes')||'').trim(),reviewed:trip.issues.length?data.has('reviewed'):trip.reviewed};
    if(commit(trips.map(item=>item.id===updated.id?updated:item))){detailDraft=null;render();toast('Trip changes saved');}
  } else if(form.id==='correction-form'){
    const trip=trips.find(item=>item.id===selectedId),use=data.has('correction'),input=String(data.get('adjustedMiles')||'').trim(),reason=String(data.get('reason')||'').trim();
    if(use&&(input===''||!Number.isFinite(Number(input))||Number(input)<0||!reason)){showError('Enter valid miles and explain the source of your correction.');return;}
    const updated={...trip,...detailDraft,adjustedMiles:use?Number(input):null,adjustmentReason:use?reason:''};
    if(commit(trips.map(item=>item.id===updated.id?updated:item))){sheet.close();detailDraft=null;render();toast('Mileage correction saved');}
  } else if(form.id==='add-trip-form'){
    const started=new Date(data.get('startedAt')),ended=new Date(data.get('endedAt')),total=Number(data.get('miles')),from=String(data.get('from')).trim(),to=String(data.get('to')).trim(),reason=String(data.get('reason')).trim();
    if(!Number.isFinite(started.getTime())||!Number.isFinite(ended.getTime())||ended<started||!Number.isFinite(total)||total<0||!from||!to||!reason){showError('Enter valid locations, miles, a source, and an end time after the start.');return;}
    const trip={...makeTrip(data.get('category'),String(data.get('purpose')||'').trim(),started.toISOString()),endedAt:ended.toISOString(),routeTitle:`${from} → ${to}`,startLocation:from,endLocation:to,adjustedMiles:total,adjustmentReason:reason,issues:['Manual entry – no GPS route'],reviewed:true,manual:true,demoSeconds:(ended-started)/1000};
    if(commit([trip,...trips])){sheet.close();selectedMonth=monthKey(started);go('trips');toast('Manual preview trip saved');}
  } else if(form.id==='profile-form'){
    if(savePreferences({...preferences,profileName:String(data.get('name')||'').trim()})){sheet.close();render();toast('Local profile saved');}
  } else if(form.id==='vehicle-form'){
    const name=String(data.get('name')||'').trim();if(!name){showError('Enter a vehicle name.');return;}
    if(savePreferences({...preferences,vehicleName:name})){sheet.close();render();toast('Vehicle saved');}
  }
});
document.addEventListener('click',event=>{
  const button=event.target.closest('[data-action]');if(!button||button.disabled)return;
  const action=button.dataset.action;
  if(action==='navigate')go(button.dataset.view);
  else if(action==='active')go('active');
  else if(action==='start')startTrip();
  else if(action==='samples')loadSamples();
  else if(action==='detail')go('detail',button.dataset.id);
  else if(action==='filter'){filter=button.dataset.value;render();app.querySelector('[data-action="filter"][aria-pressed="true"]')?.focus({preventScroll:true});}
  else if(action==='search'){showSearch=!showSearch;if(!showSearch)query='';render();document.getElementById('search')?.focus();}
  else if(action==='active-category'){const trip=active();if(trip&&commit(trips.map(item=>item.id===trip.id?{...item,category:button.dataset.value}:item)))render();}
  else if(action==='detail-category'){if(detailDraft){detailDraft.category=button.dataset.value;renderDetail();app.querySelector('[data-action="detail-category"][aria-pressed="true"]')?.focus({preventScroll:true});}}
  else if(action==='pause'){const trip=active();if(trip&&commit(trips.map(item=>item.id===trip.id?{...item,paused:true}:item))){render();toast('Simulation paused');}}
  else if(action==='resume'){const trip=active();if(trip&&commit(trips.map(item=>item.id===trip.id?{...item,paused:false,interrupted:false}:item))){render();toast('Simulation resumed');}}
  else if(action==='stop')confirmation('End this drive?','Your simulated route and mileage will be saved to Trips.','End and save drive','confirm-stop');
  else if(action==='confirm-stop'){
    const trip=active();if(!trip)return;const updated={...trip,endedAt:new Date().toISOString(),paused:false};
    if(trip.gpsMiles===0)updated.issues=[...trip.issues,'Not enough simulated points to measure the drive'];
    if(commit(trips.map(item=>item.id===trip.id?updated:item))){sheet.close();go('detail',trip.id);toast('Drive saved');}
  } else if(action==='add-trip')addTripSheet();
  else if(action==='correct')correctionSheet();
  else if(action==='trip-options')openSheet('Trip options',`<button class="export-option" data-action="correct">${icon('target',19)}Correct mileage</button><button class="button danger full" data-action="delete" ${readOnly?'disabled':''}>Delete trip</button>`);
  else if(action==='delete'){confirmation('Delete this trip?','This removes this trip permanently from the browser preview.','Delete trip','confirm-delete',true);}
  else if(action==='confirm-delete'){if(commit(trips.filter(trip=>trip.id!==selectedId))){sheet.close();go('trips');toast('Trip deleted');}}
  else if(action==='report-format'){reportFormat=button.dataset.value;render();app.querySelector('[data-action="report-format"][aria-pressed="true"]')?.focus({preventScroll:true});}
  else if(action==='report-trips'){filter=button.dataset.value;query='';go('trips');}
  else if(action==='export-report'){if(reportFormat==='CSV')exportCSV(monthTrips());else printReport();}
  else if(action==='appearance')setAppearance(button.dataset.value);
  else if(action==='profile')openSheet('Local profile',`<form id="profile-form" class="stack"><p class="description">Your name is saved only in this browser. No account is created.</p><label class="form-field">Name<input class="input" name="name" maxlength="80" value="${esc(preferences.profileName)}" placeholder="Your name"></label><button class="button full" type="submit">Save profile</button></form>`);
  else if(action==='vehicle')openSheet('Manage vehicle',`<form id="vehicle-form" class="stack"><label class="form-field">Vehicle name<input class="input" name="name" maxlength="80" required value="${esc(preferences.vehicleName)}" placeholder="e.g. My vehicle"></label><p class="description">This becomes the default vehicle for new preview drives.</p><p id="form-error" class="danger-text small" role="alert" hidden></p><button class="button full" type="submit">Save vehicle</button></form>`);
  else if(action==='default-category')openSheet('Default trip type',`${segments(['Business','Personal'],preferences.defaultCategory,'set-default-category','Default trip type')}<p class="description">New drives start with this category.</p>`);
  else if(action==='set-default-category'){if(savePreferences({...preferences,defaultCategory:button.dataset.value})){sheet.close();render();toast('Default trip type saved');}}
  else if(action==='location-info')openSheet('Location access',`<p class="description">This browser preview uses simulated GPS and does not request your location.</p><p class="description">For real drives, install the native Mileage app and allow Precise Location. Start a drive while parked and the app is visible.</p>`);
  else if(action==='background-info')openSheet('Background recording',`<p class="description">The native iPhone app is configured for background location during a manually started drive. Actual locked-screen tracking needs a physical iPhone test.</p><p class="description">This preview pauses its simulation when hidden. Automatic drive detection and motion detection are not enabled.</p>`);
  else if(action==='export-options')openSheet('Export preview data',`<button class="export-option" data-action="csv" ${completed().length?'':'disabled'}>${icon('document',20)}Export completed trips as CSV</button><button class="export-option" data-action="backup">${icon('cloud',20)}Export full preview backup (JSON)</button><p class="description">Exports are labeled as simulated or manually entered browser-preview records. Preview JSON is separate from native iPhone backups.</p>`);
  else if(action==='csv')exportCSV();
  else if(action==='backup')exportBackup();
  else if(action==='reset')confirmation('Reset preview data?','All browser-preview trips, including an active drive, will be removed. Appearance and profile preferences are kept.','Reset preview','confirm-reset',true);
  else if(action==='confirm-reset'){if(commit([])){sheet.close();filter='All';query='';go('home');toast('Preview data reset');}}
  else if(action==='close')sheet.close();
});
setInterval(()=>{
  const trip=active();if(!trip||trip.interrupted||trip.paused||readOnly||document.hidden)return;
  const updated={...trip,gpsMiles:trip.gpsMiles+1/12,demoSeconds:(trip.demoSeconds||0)+10};
  if(commit(trips.map(item=>item.id===trip.id?updated:item))&&view==='active'){
    const instrument=document.getElementById('live-instrument'),route=document.getElementById('live-route');
    if(instrument)instrument.innerHTML=gauge({value:updated.gpsMiles,label:'Distance',maximum:20,timer:updated.demoSeconds});
    if(route)route.innerHTML=mapMarkup({showRoute:true,progress:Math.min(1,updated.gpsMiles/18.7)});
  }
},1000);
render();
