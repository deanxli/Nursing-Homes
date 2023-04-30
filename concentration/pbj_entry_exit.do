keep provnum year 
duplicates drop 

bys provnum: egen first_yr = min(year) 
bys provnum: egen last_yr = max(year) 

* num SNFs 
distinct provnum 

* first year 
tab year if year == first_yr 

* last year 
tab year if year == last_yr

* SNFs in the whole data period 
distinct provnum if first_yr == 2017 & last_yr == 2022
