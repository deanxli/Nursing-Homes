set more off
clear all
capture log close
program drop _all
set scheme modern
preliminaries
version 17
set maxvar 120000, perm
global hcris_data "/Users/conniexu/Dropbox (Harvard University)/NH Ownership/Nursing Homes Data/Medicare Cost Reports/Data by Year/"

program main   
    entry_exit
    maps
end

program entry_exit
    use ../external/entry_exit/comparison_of_entry_exit.dta, clear
    grstyle init
    grstyle set color Dark2

    graph bar entry exit total_acq, over(fyear, label(angle(45))) ytitle("Number of Events Per Year") legend(label(1 "Entries") label(2 "Exits") label(3 "Ownership Changes") rowgap(0) pos(11) ring(0) size(small)) 
    graph export ../output/figures/entry_exit_comp.pdf, replace
end

program maps
    * Maps with the # of Acquisitions File (break into ones exposed to “multiple in-market acquisitions”, “one in-market acquisition”, “out of market acquisitions”, “no acquisitions”
    spshape2dta ../external/geo/cb_2018_us_state_500k.shp, replace saving(usa_state)
    use usa_state_shp, clear
    merge m:1 _ID using usa_state
    destring STATEFP, replace
    drop if inlist(STATEFP,2,15,60,66,69,72,78)
    geo2xy _Y _X, proj(albers) replace
    drop _CX- _merge
    sort _ID shape_order
    save usa_state_shp_clean.dta, replace

    spshape2dta "../external/geo/cz1990.shp", replace saving(usa_cz)
    use usa_cz_shp, clear
    merge m:1 _ID using usa_cz, nogen
    destring cz, replace
    drop if inrange(cz, 34100, 34115) | inlist(cz, 35600, 34701, 34703, 34702, 34703)
    geo2xy _Y _X, proj(albers) replace
    sort _ID shape_order
    save usa_cz_shp_clean.dta, replace
   
    use ../external/geo/zip_cz, clear
    gcontract cz cz_id_1990
    drop _freq
    rename (cz cz_id_1990) (czcurrent cz)
    merge m:1 cz using usa_cz, keep(3) keepusing(cz) nogen
    gduplicates drop czcurrent, force
    rename (czcurrent cz) (cz cz_id_1990)
    save ../temp/cz_xwalk, replace
    
    use ../external/acqs/acq_count_data, clear
    foreach var in total_in_market total_all_small total_all_large {
        gen rel_`var' = `var'/number_of_nh
    }

    merge m:1 cz using ../temp/cz_xwalk , keep(3) nogen
    drop cz
    rename cz cz
    gen num_acqs = total_in_market
    gcollapse (sum) num_acqs (mean) rel*, by(cz)
    save ../temp/acq_count_data, replace

    use ../external/hhi/cz_rn_hhi_xw.dta
    merge m:1 cz using ../temp/cz_xwalk , keep(3) nogen
    drop cz
    rename cz cz
    keep if year == 2022
    gduplicates drop year cz, force
    save ../temp/hhi, replace

    use usa_cz, clear
    destring _all, replace
    merge 1:1 cz using ../temp/acq_count_data, assert(1 2 3) keep(1 3) nogen
    merge 1:1 cz using ../temp/hhi, assert(1 2 3) keep(1 3) nogen
    gen cat = 0 if num_acqs == 0
    replace cat = 1 if num_acqs == 1
    replace cat = 2 if num_acqs > 1
    replace cat = 0 if mi(cat)
    label define cat 0 "No acquisitions" 1 "1 acquisition" 2 "More than 1 acquisition"
    label values cat cat
    colorpalette //j
     #e8e8e8 #bddede #8ed4d4 #5ac8c8 ///
     #dabdd4 #bdbdd4 #8ebdd4 #5abdc8 ///
     #cc92c1 #bd92c1 #8e92c1 #5a92c1 ///
     #be64ac #bd64ac #8e64ac #5a64ac , nograph 
    local colors `r(p)'
    qui sum hhi
    local max = r(max)
    spmap hhi using usa_cz_shp_clean, id(_ID) fcolor(BuPu) clmethod(custom) clbreak(0 1000 1500 2500 `max') ///
      ocolor(white ..) osize(0.02 ..) ndfcolor(white) ndocolor(gs6 ..) ndsize(0.03 ..) ndlabel("No data") ///
      polygon(data("usa_cz_shp_clean") ocolor(gs5) osize(0.15)) ///
      legend(pos(7) size(1.75))  legstyle(1) legorder(hilo) /// 
      note("CZ HHI", size(1.5))
    graph export ../output/figures/hhi_map.pdf, replace
    spmap cat using usa_cz_shp_clean, id(_ID) fcolor(BuPu) clmethod(unique) ///
      ocolor(white ..) osize(0.02 ..) ndfcolor(gs4) ndocolor(gs6 ..) ndsize(0.03 ..) ndlabel("No data") ///
      polygon(data("usa_cz_shp_clean") ocolor(gs5) osize(0.15)) ///
      legend(pos(7) size(1.75))  legstyle(1) legorder(hilo) /// 
      note("Number of in-market acquisitions", size(1.5))
    graph export ../output/figures/cat_map.pdf, replace
end
main
