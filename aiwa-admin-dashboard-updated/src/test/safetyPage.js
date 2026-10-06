// R5 follow-up: api.safetyPage resolves to one server page of the SOS queue. pg(rows) is that answer for a whole queue
// that fits on the page (the oldest open alert is the last row: the queue is listed newest first).
export const pg = (rows) => ({ rows, total: rows.length, totalPages: 1, oldest: rows.length ? rows[rows.length - 1] : null });
