-- dbi:Gofer:transport=stream;url=ssh:mjesec.ffzg.hr;dsn=DBI:Pg:dbname=wopi_zahtjevknjige

select *,date(unesen) from zahtjevknjige ;
