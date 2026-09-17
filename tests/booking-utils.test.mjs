import {test} from 'node:test';
import assert from 'node:assert/strict';
import {escapeHTML,safeImage,safeCalendly,weekStart,dayKey,outstanding,calendarFile} from '../assets/js/booking-utils.js';
test('untrusted room content and image URLs cannot become executable markup',()=>{assert.equal(escapeHTML('<img onerror="x">'),'&lt;img onerror=&quot;x&quot;&gt;');assert.equal(safeImage('javascript:alert(1)'),'assets/images/logo.png');assert.equal(safeImage('assets/images/../../private'),'assets/images/logo.png');assert.equal(safeCalendly('https://calendly.com.evil.test/foo'),'');});
test('Nairobi week boundaries are independent of the visitor timezone',()=>{assert.equal(dayKey(new Date('2026-09-06T22:00:00Z')),'2026-09-07');assert.equal(weekStart('2026-09-06'),'2026-08-31');assert.equal(weekStart('2026-09-07'),'2026-09-07');});
test('void payments restore the outstanding balance',()=>{assert.equal(outstanding({id:'a',price:1000},[{booking_id:'a',amount:400,status:'paid'},{booking_id:'a',amount:600,status:'void'}]),600);});
test('calendar export uses absolute timestamps and escapes event text',()=>{const text=calendarFile({id:'abc',space_name:'Studio, one\nTwo',starts_at:'2026-09-07T09:00:00+03:00',ends_at:'2026-09-07T10:00:00+03:00'});assert.ok(text.includes('DTSTART:20260907T060000Z'));assert.ok(text.includes('SUMMARY:Studio\\, one\\nTwo'));assert.ok(text.endsWith('END:VCALENDAR\r\n'));});

test('shared month boundaries normalize leap years and year rollover',async()=>{
 const {calendarMonth,calendarDate,overlapsDay}=await import('../assets/js/booking-utils.js');
 assert.equal(calendarDate(2026,9,0),'2026-09-30');
 for(const [year,month,count,end] of [[2026,8,30,'2026-10-01'],[2028,1,29,'2028-03-01'],[2026,11,31,'2027-01-01']]){
  const range=calendarMonth(year,month);
  assert.equal(range.cells.filter(Boolean).length,count);
  assert.equal(range.end,`${end}T00:00:00+03:00`);
  assert.ok(Number.isFinite(new Date(range.start).getTime()));
  assert.ok(Number.isFinite(new Date(range.end).getTime()));
 }
 const event={starts_at:'2026-08-31T21:00:00Z',ends_at:'2026-09-03T21:00:00Z'};
 assert.equal(overlapsDay(event,'2026-09-02'),true);
 assert.equal(overlapsDay(event,'2026-09-04'),false);
 assert.equal(overlapsDay(event,'2026-08-31'),false);
});
