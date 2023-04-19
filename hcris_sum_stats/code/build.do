set more off
clear all
capture log close
program drop _all
set scheme modern
preliminaries
version 17
set maxvar 120000, perm

program main   
    clean_hcris
    *sum_wages
end

program clean_hcris
    forval yr = 1995/2012 {
        import delimited using "../external/samp/SNFFY`yr'/snf_`yr'_NMRC.CSV", clear
        keep if v2 == "S300005"
        keep if v4 == "00500"
        keep if inlist(v3, 100, 200, 300, 1400, 1500, 1600)
        gen yr = `yr'
        save ../temp/wage`yr', replace
    }
    forval yr = 2013/2021 {
        import delimited using "../external/samp/SNF10FY`yr'/SNF10_`yr'_NMRC.CSV", clear
        keep if v2 == "S300005"
        keep if v4 == "00500"
        keep if inlist(v3, 100, 200, 300, 1400, 1500, 1600)
        gen yr = `yr'
        save ../temp/wage`yr', replace
    }
    clear
    forval yr = 1995/2021 { 
        append using ../temp/wage`yr', clear
    }
    save ../temp/nh_hcris_wages, replace

    foreach v in 100 200 300 1400 1500 1600 {
        qui sum v5 if v3 == `v', d 
        local p99_`v' = r(p99)
        sum v5 if v3 == `v' &  v5 <= `p99_`v'', d 
        local mean_`v' = round(r(mean), 0.01)
        local med_`v' = round(r(p50), 0.01)
    }

    tw hist v5 if v3 == 100 & v5 <= `p99_100', frac color(lavender%40) xline(`mean_100', lcolor(black) lpattern(dash)) || ///
       hist v5 if v3 == 200 &  v5 <= `p99_200', frac color(emerald%40) xline(`mean_200', lcolor(black) lpattern(dash)) || ///
       hist v5 if v3 == 300 &  v5 <= `p99_300', frac color(navy%40)  xline(`mean_300', lcolor(black) lpattern(dash)) ///
       ytitle("Fraction of Nursing Homes") xtitle("Hourly Wage") xlabel(0(10)80) legend(on label(1 "RN avg. wage = `mean_100'") ///
                                        label(2 "LPN avg. wage = `mean_200'") ///
                                        label(3 "CNA avg. wage = `med_300'") pos(1) ring(0) region(lwidth(none))) 
    graph export ../output/figures/wage_direct.pdf, replace
end
program sum_wages 
    import delimited using "../external/samp/SNF10_2016_NMRC.CSV", clear 
    keep if v2 == "S300005"
    keep if v4 == "00500"
    keep if inlist(v3, 100, 200, 300)
    foreach v in 100 200 300 {
        qui sum v5 if v3 == `v', d 
        local p99_`v' = r(p99)
        sum v5 if v3 == `v' &  v5 <= `p99_`v'', d 
        local mean_`v' = round(r(mean), 0.01)
        local med_`v' = round(r(p50), 0.01)
    }

    tw hist v5 if v3 == 100 & v5 <= `p99_100', frac color(lavender%40) xline(`mean_100', lcolor(black) lpattern(dash)) || ///
       hist v5 if v3 == 200 &  v5 <= `p99_200', frac color(emerald%40) xline(`mean_200', lcolor(black) lpattern(dash)) || ///
       hist v5 if v3 == 300 &  v5 <= `p99_300', frac color(navy%40)  xline(`mean_300', lcolor(black) lpattern(dash)) ///
       ytitle("Fraction of Nursing Homes") xtitle("Hourly Wage") xlabel(0(10)80) legend(on label(1 "RN avg. wage = `mean_100'") ///
                                        label(2 "LPN avg. wage = `mean_200'") ///
                                        label(3 "CNA avg. wage = `med_300'") pos(1) ring(0) region(lwidth(none))) 
    graph export ../output/figures/wage.eps, replace
end

main
