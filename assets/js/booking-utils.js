export const escapeHTML = value => String(value ?? '').replace(/[&<>"']/g, char => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
export const money = value => `${Number(value || 0).toLocaleString('en-KE', {maximumFractionDigits: 2})} KES`;
export const dayKey = (date = new Date()) => new Intl.DateTimeFormat('en-CA', {timeZone:'Africa/Nairobi', year:'numeric',month:'2-digit',day:'2-digit'}).format(date);
export const timeLabel = value => new Intl.DateTimeFormat('en-GB', {timeZone:'Africa/Nairobi',hour:'2-digit',minute:'2-digit'}).format(new Date(value));
export const dateLabel = value => new Intl.DateTimeFormat('en-GB', {timeZone:'Africa/Nairobi',day:'numeric',month:'short',year:'numeric'}).format(new Date(value));
export function weekStart(value = dayKey()) { const d = new Date(`${value}T12:00:00+03:00`); d.setUTCDate(d.getUTCDate() - (d.getUTCDay() + 6) % 7); return dayKey(d); }
export function safeImage(value) {
  if (/^assets\/images\/[a-zA-Z0-9._/-]+$/.test(value || '') && !value.includes('..')) return value;
  try { const u = new URL(value); if(u.protocol === 'https:') return u.href; } catch {}
  return 'assets/images/logo.png';
}
export function safeCalendly(value) { try { const u = new URL(value); return u.protocol === 'https:' && u.hostname === 'calendly.com' ? u.href : ''; } catch { return ''; } }
export function outstanding(booking, payments) { return Math.max(0,Number(booking.price)-payments.filter(p=>p.booking_id===booking.id && p.status==='paid').reduce((sum,p)=>sum+Number(p.amount),0)); }
export function calendarFile(booking) {
  const stamp = v => new Date(v).toISOString().replace(/[-:]/g,'').replace(/\.\d{3}/,'');
  const text = v => String(v).replace(/\\/g,'\\\\').replace(/\r?\n/g,'\\n').replace(/;/g,'\\;').replace(/,/g,'\\,');
  return ['BEGIN:VCALENDAR','VERSION:2.0','PRODID:-//Santuri East Africa//Bookings//EN','CALSCALE:GREGORIAN','BEGIN:VEVENT',`UID:${booking.id}@bookings.santuri.org`,`DTSTAMP:${stamp(new Date())}`,`DTSTART:${stamp(booking.starts_at)}`,`DTEND:${stamp(booking.ends_at)}`,`SUMMARY:${text(booking.space_name)} — Santuri`,`LOCATION:${text('Santuri East Africa, Basement, The Mall, Westlands, Nairobi')}`,'STATUS:CONFIRMED','END:VEVENT','END:VCALENDAR',''].join('\r\n');
}
