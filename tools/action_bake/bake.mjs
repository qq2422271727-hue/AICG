// ASHWAKE v0.6 action source. Node is an OFFLINE authoring dependency only.
// All sprite pixels, blade-tip ribbons and runtime sockets use hero() geometry.
import {hero, Raster, geometryChecks, W, H, PX, PY} from './hero_skin.mjs';
import {encodePNG} from './vendor/pixelfx/png.mjs';
import {mkdirSync, readFileSync, writeFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {join} from 'node:path';
import {createHash} from 'node:crypto';

const ROOT=fileURLToPath(new URL('../../',import.meta.url));
const REVIEW=fileURLToPath(new URL('./review/',import.meta.url));
const CHECK_ONLY=process.argv.includes('--check');
const outputHashes={};
function emitAsset(path,data){
  const bytes=Buffer.from(data);
  if(CHECK_ONLY){
    if(!readFileSync(path).equals(bytes))throw Error(`Rebake differs from checked-in asset: ${path}`);
  }else writeFileSync(path,bytes);
  outputHashes[path.slice(ROOT.length)]=createHash('sha256').update(bytes).digest('hex');
}
const manifest=JSON.parse(readFileSync(join(ROOT,'assets/hero/manifest.json'),'utf8'));
const idle={lean:.6,crouch:.2,fx:-7,fy:-21,bx:6,by:-19,ffx:-6,ffy:-4,fbx:4,fby:-4,weapon:'sword',sa:2.2,flow:0};
const pose=(changes)=>({...idle,...changes});
// The shared low guard carries the forward cut's weight into B. The first
// eligible hit-confirm chain (A frame 8) and B frame 0 are exactly identical.
const low=pose({lean:5,crouch:6,fx:8,fy:-16,bx:-7,by:-20,ffx:11,fbx:-9,sa:.46,flow:11,turn:.35});
const aLow={...low,sa:low.sa+Math.PI*2};

// Unwrapped angles make A's preparation travel behind/over the shoulder, then
// cut forward/down. No accidental reverse spin through the torso at startup.
const ATTACK=[
  idle,
  pose({lean:-1,crouch:1,fx:-8,fy:-26,sa:3.0,flow:2}),
  pose({lean:-2.5,crouch:2,fx:-9,fy:-31,sa:3.75,flow:3}),
  pose({lean:-3,crouch:2.5,fx:-8,fy:-32,bx:-3,by:-24,ffx:-5,fbx:5,sa:4.02,flow:4,turn:.9}),
  pose({lean:-2,crouch:3,fx:-5,fy:-31,bx:-4,by:-24,ffx:-3,fbx:5,sa:4.30,flow:5,turn:.85}),
  pose({lean:7,crouch:4,fx:17,fy:-23,bx:-8,by:-23,ffx:13,fbx:-12,sa:Math.PI*2-.28,flow:14,scY:-1,turn:.20}),
  pose({lean:7,crouch:5,fx:16,fy:-20,bx:-8,by:-22,ffx:13,fbx:-11,sa:Math.PI*2+.13,flow:15,scY:-1,turn:.20}),
  pose({lean:6,crouch:6,fx:10,fy:-17,bx:-7,by:-21,ffx:12,fbx:-10,sa:Math.PI*2+.40,flow:13,turn:.28}),
  aLow,
  {...aLow,lean:4.8,crouch:6.1,fx:7.8,flow:10},
  {...aLow,lean:4.5,crouch:6,fx:7.4,sa:Math.PI*2+.50,flow:9},
  {...aLow,lean:4,crouch:5.8,fx:7,sa:Math.PI*2+.55,flow:8},
  pose({lean:3,crouch:4.6,fx:3,fy:-24,bx:-2,by:-20,ffx:6,fbx:-5,sa:Math.PI*2+.90,flow:6,turn:.5}),
  pose({lean:1.8,crouch:2.2,fx:-2,fy:-27,bx:2,by:-20,ffx:0,fbx:1,sa:Math.PI*2+1.5,flow:3,turn:.6}),
  {...idle,sa:idle.sa+Math.PI*2},
];

// B: compress the legs, draw the hilt low, push from the rear foot, send the
// shoulder/hand upward, then let the blade follow high. Active tips rise every
// frame; the weapon is never a recolored/reversed A atlas.
const ATTACK_B=[
  low,
  {...low,lean:3,crouch:7,fx:4,fy:-15,sa:.36,bx:-1,by:-23,flow:9,turn:.6},
  {...low,lean:1,crouch:7.8,fx:-1,fy:-15,sa:.32,bx:4,by:-25,flow:8,turn:.8},
  {...low,lean:.5,crouch:7.8,fx:0,fy:-14,sa:.30,bx:4,by:-25,flow:7,turn:.8},
  {...low,lean:6,crouch:5.5,fx:12,fy:-16,sa:.27,bx:-5,by:-24,ffx:12,flow:13,turn:.25},
  {...low,lean:6,crouch:3,fx:17,fy:-23,sa:-.22,bx:-7,by:-25,ffx:12,flow:15,turn:.15},
  {...low,lean:3,crouch:1,fx:13,fy:-29,sa:-.72,bx:-5,by:-25,ffx:11,flow:14,turn:.22},
  {...low,lean:0,crouch:0,fx:7,fy:-30,sa:-1.10,bx:-4,by:-25,ffx:10,flow:12,turn:.4},
  {...low,lean:-2,crouch:.5,fx:4,fy:-28,sa:-1.28,bx:-2,by:-24,ffx:9,fbx:-8,flow:10,turn:.5},
  {...low,lean:-2,crouch:.6,fx:1,fy:-27,sa:-1.45,bx:0,by:-23,ffx:7,fbx:-6,flow:8,turn:.6},
  pose({lean:-1.5,crouch:.8,fx:-3,fy:-25,sa:-1.70,bx:2,by:-22,ffx:4,fbx:-3,flow:6}),
  pose({lean:-1,crouch:.7,fx:-5,fy:-23,sa:-2.15,bx:3,by:-21,ffx:1,fbx:0,flow:4}),
  pose({lean:0,crouch:.5,fx:-7,fy:-22,sa:-2.70,bx:4,by:-20,ffx:-2,fbx:2,flow:3}),
  pose({lean:.4,crouch:.3,fx:-8,fy:-21,sa:-3.40,bx:5,by:-19,ffx:-4,fbx:3,flow:1}),
  {...idle,sa:idle.sa-Math.PI*2},
];

const mix=(a,b,t)=>a.map((v,i)=>v+(b[i]-v)*t);
const blend=(a,b,t)=>Object.fromEntries([...new Set([...Object.keys(a),...Object.keys(b)])].map(k=>[k,typeof a[k]==='number'&&typeof b[k]==='number'?a[k]+(b[k]-a[k])*t:b[k]??a[k]]));
const poseAt=(poses,t)=>{const a=Math.max(0,Math.min(poses.length-1,t)),i=Math.floor(a);return blend(poses[i],poses[Math.min(i+1,poses.length-1)],a-i);};
function blit(dst,src,x,y=0){
  for(let sy=0;sy<src.h;sy++)for(let sx=0;sx<src.w;sx++){
    dst.buf.set(src.buf.subarray((sy*src.w+sx)*4,(sy*src.w+sx)*4+4),((sy+y)*dst.w+x+sx)*4);
  }
}
function samePixels(a,b){return a.buf.every((v,i)=>v===b.buf[i]);}
function opaqueNear(r,p){
  for(let dy=-2;dy<=2;dy++)for(let dx=-2;dx<=2;dx++){
    const x=Math.round(p[0])+dx,y=Math.round(p[1])+dy;
    if(x>=0&&y>=0&&x<r.w&&y<r.h&&r.buf[(y*r.w+x)*4+3]>0)return true;
  }
  return false;
}
function stats(r){
  let count=0,alphaSum=0,maxAlpha=0,minX=r.w,minY=r.h,maxX=-1,maxY=-1;
  for(let y=0;y<r.h;y++)for(let x=0;x<r.w;x++){
    const a=r.buf[(y*r.w+x)*4+3];if(!a)continue;
    count++;alphaSum+=a;maxAlpha=Math.max(maxAlpha,a);minX=Math.min(minX,x);minY=Math.min(minY,y);maxX=Math.max(maxX,x);maxY=Math.max(maxY,y);
  }
  return {pixels:count,alphaSum,maxAlpha,bbox:count?[minX,minY,maxX,maxY]:null};
}
// Tip path ribbons are narrow bands (not a filled sector). They occupy only
// the outside of the blade's sweep and a slim edge on the current blade.
// Straight RGBA, no blur, no premultiplication, no character pixels.
function trail(poses,i,firstActive,lastActive){
  const r=new Raster();
  const fade=i<=lastActive?1:[.34,.12,.025][i-lastActive-1]??0;
  if(i<firstActive||fade===0)return r;
  const history=i<=lastActive?(i===firstActive?.65:.88):.42;
  const samples=[],segments=20;
  for(let j=0;j<=segments;j++)samples.push(hero(poseAt(poses,i-history+history*j/segments)).weaponSocket);
  // Sweep a tapered strip just inside the real blade tip, not a bright
  // one-pixel path. The newest cross-section is ~4 px wide; its older end
  // closes to a point and loses alpha. Radial section vectors follow the
  // blade orientation, avoiding detached right-angle/electrical-looking lines.
  const section=(s,t)=>{
    const dx=s.tip[0]-s.root[0],dy=s.tip[1]-s.root[1],len=Math.hypot(dx,dy)||1;
    const u=[dx/len,dy/len],width=3.5*Math.pow(t,.65),outer=.45*t;
    const at=(distance)=>[s.tip[0]+u[0]*distance,s.tip[1]+u[1]*distance];
    return {at,width,outer};
  };
  for(let j=1;j<samples.length;j++){
    const t0=(j-1)/segments,t1=j/segments,a=section(samples[j-1],t0),b=section(samples[j],t1);
    const band=(outerFraction,innerFraction,color)=>r.poly([
      a.at(a.outer-a.width*outerFraction),a.at(a.outer-a.width*innerFraction),
      b.at(b.outer-b.width*innerFraction),b.at(b.outer-b.width*outerFraction)
    ],color);
    band(0,1,[67,174,177,Math.round(205*Math.pow(t1,.65)*fade)]);
    band(.12,.78,[157,228,207,Math.round(240*Math.sqrt(t1)*fade)]);
    // A thin warm highlight only near the live tip; the tapered turquoise
    // body remains readable instead of one uniform white wire.
    if(t1>.55)band(.24,.43,[242,249,216,Math.round(245*t1*fade)]);
  }
  const socket=hero(poses[i]).weaponSocket;
  // A one-pixel pale leading edge joins the trail to the exact blade tip.
  r.line(mix(socket.root,socket.tip,.46),socket.tip,[233,246,213,Math.round(245*fade)]);
  r.line(mix(socket.root,socket.tip,.72),socket.tip,[252,249,216,Math.round(255*fade)]);
  return r;
}

const EXPECTED={attack:[...Array(5).fill(.01),...Array(3).fill(.039),...Array(7).fill(.019)],attack_b:[...Array(4).fill(.01675),...Array(4).fill(.025),...Array(7).fill(.019)]};
if(manifest.frame.width!==W||manifest.frame.height!==H||manifest.frame.pivot[0]!==PX||manifest.frame.pivot[1]!==PY)throw Error('Frame/pivot contract changed');
for(const clip of Object.keys(EXPECTED)){
  const rec=manifest.animations[clip];
  if(rec.frames!==15||rec.total_seconds!==.3||JSON.stringify(rec.frame_durations_seconds)!==JSON.stringify(EXPECTED[clip]))throw Error(`${clip}: existing combat dwell timings changed`);
}
mkdirSync(REVIEW,{recursive:true});
const tracks={schema_version:1,frame:{width:W,height:H,pivot:[PX,PY]},clips:{}};
const output=[],review=new Raster(W*8,H*8),perClip={},unrelatedHashes={};
for(const [clip,record] of Object.entries(manifest.animations)){
  if(clip==='attack'||clip==='attack_b')continue;
  unrelatedHashes[clip]=createHash('sha256').update(readFileSync(join(ROOT,'assets/hero',record.file))).digest('hex');
}
for(const [row,[clip,poses,first,last,trailFile]] of [
  ['attack',ATTACK,5,7,'attack_a_trail.png'],
  ['attack_b',ATTACK_B,4,7,'attack_b_trail.png'],
].entries()){
  const atlas=new Raster(W*15,H),fx=new Raster(W*15,H),frames=[],effects=[],sockets=[];
  for(let i=0;i<15;i++){
    const result=hero(poses[i]);
    const effect=trail(poses,i,first,last);
    frames.push(result.r);effects.push(effect);sockets.push(result.weaponSocket);
    blit(atlas,result.r,i*W);blit(fx,effect,i*W);
    // Review pairs: character alone above, character + ribbon below.
    const gx=(i%8)*W,gy=(row*4+Math.floor(i/8)*2)*H;
    blit(review,result.r,gx,gy);
    const merged=new Raster();blit(merged,result.r,0);
    for(let p=0;p<effect.buf.length;p+=4){
      const alpha=effect.buf[p+3]/255;if(!alpha)continue;
      const base=merged.buf[p+3]/255,outA=alpha+base*(1-alpha);
      for(let c=0;c<3;c++)merged.buf[p+c]=Math.round((effect.buf[p+c]*alpha+merged.buf[p+c]*base*(1-alpha))/outA);
      merged.buf[p+3]=Math.round(outA*255);
    }
    blit(review,merged,gx,gy+H);
  }
  tracks.clips[clip]={sockets};
  const imagePath=join(ROOT,'assets/hero',manifest.animations[clip].file),fxPath=join(ROOT,'assets/fx',trailFile);
  emitAsset(imagePath,encodePNG(atlas.w,atlas.h,atlas.buf));
  emitAsset(fxPath,encodePNG(fx.w,fx.h,fx.buf));output.push(imagePath,fxPath);
  perClip[clip]={firstActiveFrame:first,lastActiveFrame:last,frames:frames.map(stats),trails:effects.map(stats),tipY:sockets.map(s=>s.tip[1]),rootY:sockets.map(s=>s.root[1]),socketsOnPixels:sockets.every((s,i)=>opaqueNear(frames[i],s.root)&&opaqueNear(frames[i],s.tip)),framesData:frames};
}
emitAsset(join(ROOT,'assets/hero/action_tracks.json'),JSON.stringify(tracks,null,2)+'\n');
review.save(join(REVIEW,'action_review.png'));
// Nearest-neighbor focus view: A5/A6 above B5/B6, composited onto a dark
// neutral field so the authored alpha bands are reviewable at native multiples.
const closeup=new Raster(W*2*3,H*2*3);
for(let cy=0;cy<2;cy++)for(let cx=0;cx<2;cx++)for(let y=0;y<H;y++)for(let x=0;x<W;x++){
  const at=(((cy===0?1:5)*H+y)*review.w+(cx+5)*W+x)*4,a=review.buf[at+3]/255;
  const col=[0,1,2].map((k)=>Math.round(review.buf[at+k]*a+[16,29,39][k]*(1-a))).concat(255);
  for(let sy=0;sy<3;sy++)for(let sx=0;sx<3;sx++)closeup.pixel((cx*W+x)*3+sx,(cy*H+y)*3+sy,col);
}
closeup.save(join(REVIEW,'trail_closeup.png'));
const socketDistance=(a,b)=>Math.max(Math.hypot(...a.root.map((v,i)=>v-b.root[i])),Math.hypot(...a.tip.map((v,i)=>v-b.tip[i])));
const a=perClip.attack,b=perClip.attack_b;
const checks={
  frame:[W,H],pivot:[PX,PY],framesPerClip:15,totalSeconds:[manifest.animations.attack.total_seconds,manifest.animations.attack_b.total_seconds],
  maxBoneError:Math.max(...geometryChecks.map(g=>g.maxBoneError)),
  minBladeGroundClearance:Math.min(...geometryChecks.map(g=>g.bladeGroundClearance)),
  maxGeometryBelowFloor:Math.max(...geometryChecks.map(g=>g.maxGeometryY)),
  firstChainPixelIdentical:samePixels(a.framesData[8],b.framesData[0]),
  firstChainSocketDelta:socketDistance(tracks.clips.attack.sockets[8],tracks.clips.attack_b.sockets[0]),
  // The actual instant cancel displays A7 then B0, not the intermediate A8.
  lastActiveToB0RootDelta:Math.hypot(...tracks.clips.attack.sockets[7].root.map((v,i)=>v-tracks.clips.attack_b.sockets[0].root[i])),
  lastActiveToB0TipDelta:Math.hypot(...tracks.clips.attack.sockets[7].tip.map((v,i)=>v-tracks.clips.attack_b.sockets[0].tip[i])),
  whiffChainSocketDelta:socketDistance(tracks.clips.attack.sockets[11],tracks.clips.attack_b.sockets[0]),
  activeBTipY:b.tipY.slice(4,8),
  activeBRises:b.tipY.slice(5,8).every((y,i)=>y<b.tipY[i+4]),
  startupTransparent:[a,b].every(c=>c.trails.slice(0,c.firstActiveFrame).every(s=>s.pixels===0)),
  firstActiveTrailVisible:[a,b].every(c=>c.trails[c.firstActiveFrame].maxAlpha===255),
  lastFramesTransparent:[a,b].every(c=>c.trails[14].pixels===0),
  recoveryAlphaDecays:[a,b].every(c=>c.trails[8].maxAlpha<c.trails[7].maxAlpha&&c.trails[9].maxAlpha<c.trails[8].maxAlpha&&c.trails[10].maxAlpha<c.trails[9].maxAlpha&&c.trails[11].pixels===0),
  socketsOnRenderedPixels:a.socketsOnPixels&&b.socketsOnPixels,
  unrelatedAtlasHashes:unrelatedHashes,
  deterministicAssetHashes:outputHashes,
  checkOnly:CHECK_ONLY,
};
checks.passed=checks.maxBoneError<1e-6&&checks.minBladeGroundClearance>0&&checks.maxGeometryBelowFloor<.1&&checks.firstChainPixelIdentical&&checks.firstChainSocketDelta<1e-8&&checks.lastActiveToB0RootDelta<4&&checks.lastActiveToB0TipDelta<5&&checks.activeBRises&&checks.startupTransparent&&checks.firstActiveTrailVisible&&checks.lastFramesTransparent&&checks.recoveryAlphaDecays&&checks.socketsOnRenderedPixels;
for(const c of [a,b])delete c.framesData;
writeFileSync(join(REVIEW,'geometry_validation.json'),JSON.stringify({checks,clips:perClip},null,2)+'\n');
console.log(JSON.stringify(checks,null,2));
if(!checks.passed)process.exitCode=1;
