set more off
clear all
capture log close
program drop _all
set scheme modern
preliminaries
version 17
set maxvar 120000, perm

program main   
    desc_stats
end

program desc_stats 
    use ../external/samp/nh_hcris_wages, clear
    rename ccn prvdr_num
    merge m:1 prvdr_num using ../external/pos/posotherdec2021.dta, assert(1 2 3) keep(3) nogen keepusing(state_cd fips_state_cd fips_cnty_cd city_name zip_cd)
    rename (state_cd zip_cd) (state zip5)
    gen county = fips_state_cd + fips_cnty_cd
    drop c_*
    gcollapse (mean) *_wage, by(prvdr_num yr state zip5 city_name county)
    drop if mi(rn_wage) & mi(lpn_wage) & mi(cna_wage)

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
    gcollapse (mean) rn* lpn* cna*, by(prvdr_num state zip5 county)
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
           ytitle("Fraction of Nursing Homes") xtitle("`upper'") xlabel(`xlab') legend(on label(1 "RN avg. `lower' = `rn_`var'_mean'") ///
                                            label(2 "LPN avg. `lower' = `lpn_`var'_mean'") ///
                                            label(3 "CNA avg. `lower' = `cna_`var'_mean'") pos(1) ring(0) region(lwidth(none))) 
        graph export ../output/figures/`var'_dist.pdf, replace
        destring county, replace
        destring zip5, replace
        foreach loc in state county {
            preserve
            gcollapse (mean) *_wage *yoy *chg, by(`loc')
            local maptile_loc = "`loc'"
            if "`loc'" == "county" local maptile_loc = "county2014"
            foreach n in rn lpn cna {
                foreach var in wage yoy chg {
                    maptile  `n'_`var', geo(`maptile_loc') fcolor(BuPu)
                    graph export ../output/figures/`n'_`var'_`loc'.pdf, replace
                }
            }
            restore
        }
    }
end
main
