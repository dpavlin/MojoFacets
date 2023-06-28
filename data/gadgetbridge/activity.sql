-- dbi:SQLite:dbname=/srv/mojo_facets/data/gadgetbridge/Gadgetbridge
-- timefmt %Y-%m-%d %H:%M:%S

SELECT
-- "TIMESTAMP",
date(datetime("TIMESTAMP",'unixepoch','localtime')) as DATE,
datetime("TIMESTAMP",'unixepoch','localtime') as DATETIME,
STEPS,
CASE
WHEN HEART_RATE = 255 THEN NULL 
--WHEN HEART_RATE < 2   THEN 'B' 
ELSE HEART_RATE END 
as HEART_RATE, 
RAW_INTENSITY,
RAW_KIND
FROM MI_BAND_ACTIVITY_SAMPLE
WHERE RAW_INTENSITY != -1
-- and "TIMESTAMP" > unixepoch() - ( 24 * 60 * 60 * 3 ) 

-- and "TIMESTAMP" BETWEEN (strftime('%s','2019-08-02 16:15:00','utc')) and (strftime('%s','2099-08-03 23:15:00','utc'))
-- and HEART_RATE<>255
;
