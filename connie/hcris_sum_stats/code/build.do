set more off
clear all
capture log close
program drop _all
set scheme modern
graph set window fontface "Arial Narrow"
preliminaries
version 17
set maxvar 120000, perm

program main   
    desc_stats
    within_mkt_stats
    maps
end

program desc_stats 
    use ../external/samp/nh_hcris_wages, clear
    rename ccn prvdr_num
    merge m:1 prvdr_num using ../external/pos/posotherdec2021.dta, assert(1 2 3) keep(3) nogen keepusing(state_cd fips_state_cd fips_cnty_cd city_name zip_cd)
    rename (state_cd zip_cd) (state zip5)
    gen county = fips_state_cd + fips_cnty_cd
    rename (fips_state_cd fips_cnty_cd) (STATEFP COUNTYFP)
    destring STATEFP, replace
    destring COUNTYFP, replace
    drop c_*
    gcollapse (mean) *_wage, by(prvdr_num yr state zip5 city_name county STATEFP COUNTYFP)
    drop if mi(rn_wage) | mi(lpn_wage) | mi(cna_wage)
    save ../temp/prvdr_yr_wages, replace

    // distribution of average year-over-year-growth 
    foreach n in rn lpn cna {
        bys prvdr_num (yr) : gen `n'_yoy = (`n'_wage-`n'_wage[_n-1])/(`n'_wage[_n-1]*(yr-yr[_n-1]))*100
    }
    bys prvdr_num (yr) : gen yr_id = _n

    foreach n in rn lpn cna {
        bys prvdr_num (yr): egen min_yr_`n' = min(yr_id) if !mi(`n'_wage)
        bys prvdr_num (yr): egen max_yr_`n' = max(yr_id) if !mi(`n'_wage)
        gen `n'_wage_min = `n'_wage if yr_id == min_yr_`n'
        gen `n'_wage_max = `n'_wage if yr_id == max_yr_`n'
        bys prvdr_num (yr): egen `n'_min = max(`n'_wage_min)
        bys prvdr_num (yr): egen `n'_max = max(`n'_wage_max)
        gen `n'_chg =  (`n'_max - `n'_min)/`n'_min *100
    }
    drop *min* *max*
    preserve
        gcollapse (mean) *wage, by(yr)
        foreach n in rn lpn cna {
            qui sum `n'_wage if yr == 2011
            gen `n'_wage_adj = `n'_wage - r(mean)
            gen `n'_yoy = (`n'_wage-`n'_wage[_n-1])/ `n'_wage[_n-1] * 100
            replace `n'_yoy = 0 if mi(`n'_yoy)
        }

        tw line rn_wage_adj yr, color(lavender) || ///
           line lpn_wage_adj yr , color(emerald) || ///
           line cna_wage_adj  yr, color(navy) ///
           ytitle("Average Hourly Wage") xtitle("`upper'") xlabel(2011(1)2022) legend(on label(1 "RN") ///
                                            label(2 "LPN") ///
                                            label(3 "CNA") pos(1) ring(0) region(lwidth(none))) 
        graph export ../output/figures/wage_trends.pdf, replace
        tw line rn_yoy yr, color(lavender) || ///
           line lpn_yoy yr , color(emerald) || ///
           line cna_yoy yr, color(navy) ///
           ytitle("Year-over-year % Change in Hourly Wages") xtitle("`upper'") xlabel(2011(1)2022) legend(on label(1 "RN") ///
                                            label(2 "LPN") ///
                                            label(3 "CNA") pos(1) ring(0) region(lwidth(none))) 
        graph export ../output/figures/yoy_trends.pdf, replace
    restore
    gcollapse (mean) *wage *yoy *chg, by(prvdr_num state zip5 county STATEFP COUNTYFP)
    local N = 0
    foreach n in rn lpn cna {
        qui sum `n'_wage, d
        local `n'_wage_mean: di %04.3f r(mean)
        local `n'_wage_med: di %04.3f r(p50)
        local N = max(`N',r(N))
        qui sum `n'_yoy, d
        local `n'_yoy_mean: di %04.3f r(mean)
        qui sum `n'_chg, d
        local `n'_chg_mean: di %04.3f r(mean)
        gen `n'_sd = `n'_wage
    }
    
    // average wage across years for all NH
    foreach var in wage yoy chg {
        if "`var'" == "wage" local upper = "Hourly Wage"
        if "`var'" == "wage" local lower = "wage"
        if "`var'" == "yoy" local upper = "Year-over-year % Change"
        if "`var'" == "yoy" local lower = "yoy % change"
        if "`var'" == "chg" local upper = "Overall % Change"
        if "`var'" == "chg" local lower = "overall % change"
        if "`var'" == "wage" local xlab = "0(10)80" 
        if "`var'" == "yoy" local xlab = "-80(20)200" 
        if "`var'" == "chg" local xlab = "-80(20)200" 
        tw hist rn_`var', frac color(lavender%60) xline(`rn_`var'_mean', lcolor(black) lpattern(dash)) || ///
           hist lpn_`var', frac color(emerald%60) xline(`lpn_`var'_mean', lcolor(black) lpattern(dash)) || ///
           hist cna_`var', frac color(navy%60)  xline(`cna_`var'_mean', lcolor(black) lpattern(dash)) ///
           ytitle("Proportion of Nursing Homes") xtitle("`upper'") xlabel(`xlab') legend(on label(1 "RN avg. `lower' = `rn_`var'_mean'") ///
                                            label(2 "LPN avg. `lower' = `lpn_`var'_mean'") ///
                                            label(3 "CNA avg. `lower' = `cna_`var'_mean'") pos(1) ring(0) region(lwidth(none))) 
        graph export ../output/figures/`var'_dist.pdf, replace
    }
        *destring county, replace
        *destring zip5, replace
    save ../temp/prvdr_num_wages, replace 
    gcollapse (mean) *wage *yoy *chg (sd) *sd, by(STATEFP COUNTYFP)
    save ../temp/collapsed_geo_wages, replace 
        /*foreach loc in state county {
            preserve
            gcollapse (mean) *_wage *yoy *chg, by(`loc')
            local maptile_loc = "`loc'"
            if "`loc'" == "county" local maptile_loc = "county2010"
            foreach n in rn lpn cna {
                foreach var in wage yoy chg {
                    maptile  `n'_`var', geo(`maptile_loc') fcolor(PuBu)
                    graph export ../output/figures/`n'_`var'_`loc'.pdf, replace
                }
            }
            restore
        }*/
end

program within_mkt_stats
    use ../temp/prvdr_yr_wages, clear
    foreach n in rn lpn cna {
        bys county yr: egen county_yr_`n'_avg = mean(`n'_wage)
        bys county yr: gen within_mkt_diff_`n' = `n'_wage - county_yr_`n'_avg
        qui sum within_mkt_diff_`n', d
        local `n'_N = r(N)
        local `n'_mean: di %4.3f r(mean)
        local `n'_sd: di %4.3f r(sd)
    }
    bys county yr : gen num_NH = _N
    tw hist within_mkt_diff_rn, frac color(lavender%60) xline(`rn_mean', lcolor(black) lpattern(dash)) || ///
       hist within_mkt_diff_lpn, frac color(emerald%60) xline(`lpn_mean', lcolor(black) lpattern(dash)) || ///
       hist within_mkt_diff_cna, frac color(navy%60)  xline(`cna_mean', lcolor(black) lpattern(dash)) ///
       ytitle("Proportion of Nursing Homes") xtitle("NH Wage - County Average") xlabel(-50(10)50) legend(on label(1 "RN:" "mean = `rn_mean'" "           (`rn_sd')") ///
                                        label(2 "LPN:" "mean = `lpn_mean'" "           (`lpn_sd')") ///
                                        label(3 "CNA:" "mean = `cna_mean'" "           (`cna_sd')") pos(1) ring(0) region(lwidth(none))) 
    graph export ../output/figures/within_county_diff.pdf, replace
    foreach n in lpn rn {
        corr within_mkt_diff_cna within_mkt_diff_`n'
        local corr = r(rho)
        binscatter within_mkt_diff_cna within_mkt_diff_`n', legend(on order(- "Corr = `corr'") ring(0) pos(1))
        graph export ../output/figures/within_corr_cna_`n'.pdf, replace
    }

    gcollapse (sd) *wage, by(county yr)
    foreach n in rn lpn cna {
        qui sum `n'_wage, d
        local `n'_mean: di %4.3f r(mean)
        local `n'_sd: di %4.3f r(sd)
    }
    tw hist rn_wage, frac color(lavender%60) xline(`rn_mean', lcolor(black) lpattern(dash)) || ///
       hist lpn_wage, frac color(emerald%60) xline(`lpn_mean', lcolor(black) lpattern(dash)) || ///
       hist cna_wage, frac color(navy%60)  xline(`cna_mean', lcolor(black) lpattern(dash)) ///
       ytitle("Proportion of Nursing Homes") xtitle("Standard Deviation Within County-Year") xlabel(0(5)30) legend(on label(1 "RN:" "mean = `rn_mean'" "           (`rn_sd')") ///
                                        label(2 "LPN:" "mean = `lpn_mean'" "           (`lpn_sd')") ///
                                        label(3 "CNA:" "mean = `cna_mean'" "           (`cna_sd')") pos(1) ring(0) region(lwidth(none))) 
    graph export ../output/figures/within_county_sd.pdf, replace
end 
program maps
*    set scheme white_tableau
    spshape2dta ../external/geo/cb_2018_us_state_500k.shp, replace saving(usa_state)
    use usa_state_shp, clear
    merge m:1 _ID using usa_state
    destring STATEFP, replace 
    drop if inlist(STATEFP,2,15,60,66,69,72,78)
    geo2xy _Y _X, proj(albers) replace
    drop _CX- _merge
    sort _ID shape_order
    save usa_state_shp_clean.dta, replace

    spshape2dta "../external/geo/cb_2018_us_county_500k.shp", replace saving(usa_county)
    use usa_county_shp, clear
    merge m:1 _ID using usa_county
    destring STATEFP, replace 
    drop if inlist(STATEFP,2,15,60,66,69,72,78)
    drop _CX- _merge 
    geo2xy _Y _X, proj(albers) replace
    sort _ID shape_order
    save usa_county_shp_clean.dta, replace

    use usa_county, clear
    destring _all, replace
    merge 1:1 STATEFP COUNTYFP using ../temp/collapsed_geo_wages,assert(1 2 3) keep(3) nogen
    colorpalette ///
     #e8e8e8 #bddede #8ed4d4 #5ac8c8 ///
     #dabdd4 #bdbdd4 #8ebdd4 #5abdc8 ///
     #cc92c1 #bd92c1 #8e92c1 #5a92c1 ///
     #be64ac #bd64ac #8e64ac #5a64ac , nograph 
    local colors `r(p)'
    foreach n in rn lpn cna {
       egen cut_`n'_wage = cut(`n'_wage), at(0,10,20,30,40,50,60,70) icodes
       xtile xtile_`n'_wage = `n'_wage, n(4)
    }
    foreach n in rn lpn cna {
/*        qui sum `n'_wage, d
        local clb_wage = "r(p5) r(p10) r(p25) r(p50) r(p75) r(p90) r(p99)"
        qui sum `n'_sd, d
        local clb_sd = "r(p5) r(p10) r(p25) r(p50) r(p75) r(p90) r(p99)"*/
        // min p10 p25 p50 p75 p90 max
        if "`n'" == "rn" local clb_wage "18 28 31 34 38 41 63"
        if "`n'" == "rn" local clb_sd "0 1 2.1 3.5 4.7 6.1 19"
        if "`n'" == "lpn" local clb_wage "16 21 23 25 28 32 50"
        if "`n'" == "lpn" local clb_sd "0 .7 1.4 2.3 3.2 4.2 10.5"
        if "`n'" == "cna" local clb_wage "8 11 13 15 17 19 30"
        if "`n'" == "cna" local clb_sd "0 .5 .9 2.1 2.9 7.7"
        spmap `n'_wage using usa_county_shp_clean,  id(_ID) clm(custom) clb(`clb_wage') fcolor(BuPu) ///
          ocolor(white ..) osize(0.02 ..) ndfcolor(gs4) ndocolor(gs6 ..) ndsize(0.03 ..) ndlabel("No data") /// 
          polygon(data("usa_state_shp_clean") ocolor(gs5) osize(0.15)) ///
          legend(pos(5) size(2.5))  legstyle(2) 
        graph export ../output/figures/`n'_map.pdf, replace
        spmap `n'_sd using usa_county_shp_clean,  id(_ID) clm(custom) clb(`clb_sd')  fcolor(BuPu) ///
          ocolor(white ..) osize(0.02 ..) ndfcolor(gs4) ndocolor(gs6 ..) ndsize(0.03 ..) ndlabel("No data") /// 
          polygon(data("usa_state_shp_clean") ocolor(gs5) osize(0.15)) ///
          legend(pos(5) size(2.5))  legstyle(2) 
        graph export ../output/figures/`n'_sd_map.pdf, replace
    }
    foreach n in rn lpn {
        local name = strupper("`n'")
        gsort xtile_`n'_wage xtile_cna_wage
        egen grp_`n'_cna_xtile = group(xtile_`n'_wage xtile_cna_wage)
        spmap grp_`n'_cna_xtile using usa_county_shp_clean,  id(_ID) clm(unique)  fcolor("`colors'") ///
          ocolor(white ..) osize(0.02 ..) ndfcolor(gs4) ndocolor(gs6 ..) ndsize(0.03 ..) ndlabel("No data") /// 
          polygon(data("usa_state_shp_clean") ocolor(gs5) osize(0.15)) ///
          legend(off) name(bivar_xtile_`n'_cna, replace)
    }

    clear 
    set obs 16 
    egen y = seq(), b(4)  
    egen x = seq(), t(4)
    twoway (scatter y x, msymbol(square) msize(18)), xlabel(0 5) ylabel(0 5) aspect(1) xsize(1) ysize(1)
    colorpalette ///
     #e8e8e8 #bddede #8ed4d4 #5ac8c8 ///
     #dabdd4 #bdbdd4 #8ebdd4 #5abdc8 ///
     #cc92c1 #bd92c1 #8e92c1 #5a92c1 ///
     #be64ac #bd64ac #8e64ac #5a64ac , nograph 
    return list
    local color11 `r(p1)'
    local color12 `r(p2)'
    local color13 `r(p3)'
    local color14 `r(p4)'
    local color21 `r(p5)'
    local color22 `r(p6)'
    local color23 `r(p7)'
    local color24 `r(p8)'
    local color31 `r(p9)'
    local color32 `r(p10)'
    local color33 `r(p11)'
    local color34 `r(p12)'
    local color41 `r(p13)'
    local color42 `r(p14)'
    local color43 `r(p15)'
    local color44 `r(p16)'
    levelsof x, local(xlvl) 
    levelsof y, local(ylvl)
    local boxes
    foreach x of local xlvl {
        foreach y of local ylvl {
            local boxes `boxes' (scatter y x if x==`x' & y==`y', msymbol(square) msize(5) mc("`color`x'`y''")) 
        }
   }

    foreach n in rn lpn {
        local upper = strupper("`n'")
        cap drop spike*
        gen spike1_x1  = 0.2 in 1
        gen spike1_x2  = 4.1 in 1 
        gen spike1_y1  = 0.2 in 1 
        gen spike1_y2  = 0.2 in 1 
        gen spike1_m   = "Higher `upper' Wages"   
          
        gen spike2_y1  = 0.2 in 1
        gen spike2_y2  = 4.1 in 1 
        gen spike2_x1  = 0.2 in 1  
        gen spike2_x2  = 0.2 in 1  
        gen spike2_m   = "Higher CNA wages"
        twoway `boxes' (pcarrow spike1_y1 spike1_x1 spike1_y2 spike1_x2, lw(thin) lcolor(gs12) mcolor(gs12) mlabel(spike1_m) mlabcolor(black) mlabpos(7 ) msize(0.5) headlabel mlabsize(2)) (pcarrow spike2_y1 spike2_x1 spike2_y2 spike2_x2, lw(thin) lcolor(gs12) mcolor(gs12) mlabel(spike2_m) mlabcolor(black) mlabpos(10) msize(0.5) headlabel mlabangle(90) mlabgap(1.8) mlabsize(2)), xlabel(0 4, nogrid) ylabel(0 4, nogrid) aspectratio(1) xsize(1) ysize(1) fxsize(19) fysize(19) legend(off) ytitle("")  xtitle("") xscale(off) yscale(off) name(bivar_legend, replace)

        graph combine bivar_xtile_`n'_cna bivar_legend, imargin(zero)
        graph export ../output/figures/bivar_xtile_`n'_cna.pdf, replace
   }
end
main
