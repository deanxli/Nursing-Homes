clear all
version 15
set more off
global outcomes "total_staff mdscensus" 

program main
    foreach geo in "county" "cz" {
        treatment_xw, geo(`geo')

        foreach variation in "constant_" "balanced_" "" {
            construct_baseline, geo(`geo') variation(`variation')

            foreach outcome in ${outcomes} {
                graph_hhi, geo(`geo') outcome(`outcome') variation(`variation')
            }
        }
    }
end

        program treatment_xw
            syntax, geo(str)

            use "../external/baseline_data", clear
            keep `geo'*
            duplicates drop
            gen acq_treatment_status = cond(`geo'_within, 2, cond(`geo'_acq_ever, 1, 0))
            save "../temp/`geo'_treatment_xw", replace
        end


    program construct_baseline
        syntax, geo(str) [variation(str)]

        use "../external/baseline_data", clear
        gen total_staff = hrs_rn + hrs_lpn + hrs_cna

        egen min_date = min(date), by(provnum)

        if "`variation'" == "constant" {
            foreach measure in ${outcomes} {
                gen first_`measure' = cond(date == min_date, `measure', .)
                egen first_`measure'_real = max(first_`measure'), by(provnum)

                replace `measure' = first_`measure'_real
            }
        }
        else if "`variation'" == "balanced" {
            egen first_date = min(date), by(provnum)
            egen last_date = max(date), by(provnum)
            keep if first_date <= 2
            keep if last_date >= 21
        }

        gen count = 1
        collapse (sum) ${outcomes}, by(large_group_id `geo' date)

        foreach measure in total_staff mdscensus {
            egen total_`measure' = sum(`measure'), by(`geo' date)


            gen `measure'_2 = (`measure' * `measure') / (total_`measure' * total_`measure') * 10000
            egen hhi_`measure' = sum(`measure'_2), by(`geo' date) 
        }

        collapse (sum) total_staff mdscensus (mean) hhi_*, by(`geo' date)

        keep `geo' date hhi_* total_staff mdscensus
        save ../output/`variation'`geo'_baseline_hhi, replace
    end

    program graph_hhi
        syntax, geo(str) outcome(str) [variation(str)]

        use ../output/`variation'`geo'_baseline_hhi, clear
        merge m:1 `geo' using ../temp/`geo'_treatment_xw, keep(3) nogen
      
            ** Normalize HHI to graph % changes
            gen hhi_early_temp = cond(date == 1, hhi_`outcome', .)
            egen hhi_early = max(hhi_early_temp), by(`geo')
            replace hhi_`outcome' = ((hhi_`outcome' - hhi_early) / hhi_early)

        collapse (mean) hhi_`outcome', by(date acq_treatment_status)

        if inlist("`outcome'", "hrs_rn") {
            local ytitle "RN Hours"
        }

        else if inlist("`outcome'", "hrs_lpn") {
            local ytitle "LPN Hours Outsourced"
        }
        else if inlist("`outcome'", "hrs_cna") {
            local ytitle "CNA Hours"
        }
        else if inlist("`outcome'", "total_staff") {
            local ytitle "Staff Hours"
        }
        else if inlist("`outcome'", "mdscensus") {
            local ytitle "Patient-Days"
        }

        ** Outliers due to reporting (COVID) and unclear what's going on in our most recent period
        drop if date == 13
        drop if date == 22

        twoway (connected hhi_`outcome' date if acq_treatment_status == 0, ///
                mcolor(maroon%70) msymbol(o) lcolor(maroon%70) lpattern(dash) lwidth(medthin)) ///
            (connected hhi_`outcome' date if acq_treatment_status == 1, ///
                mcolor(green%70) msymbol(o) lcolor(green%70) lpattern(dash) lwidth(medthin)) ///
           (connected hhi_`outcome' date if acq_treatment_status == 2, ///
                mcolor(navy%70) msymbol(o) lcolor(navy%70) lpattern(dash) lwidth(medthin)), ///
            scheme(s1mono) xtitle("") ///
            xtick(1(1)21) xsc(r(0.5 21.5)) xlabel(1 "Q1 2017" 5 "Q1 2018" 9 "Q1 2019" 13 "Q1 2020" 17 "Q1 2021" 21 "Q1 2022") ///      
            xline(13,lpattern(dash) lwidth(thin) lcolor(maroon)) ylabel(, angle(0) grid) ytitle("") ///
            subtitle("Change in HHI of `ytitle'", position(11) justification(left) size(medium)) ///
            legend(order(1 "CZs Not Affected by Acquisitions" 2 "CZs Affected by Only Out of Market Acquisitions" ///
                         3 "CZs Affected by In-Market Acquisitions") col(1))

        graph export "../figures/`variation'`geo'_trend_hhi_`outcome'.pdf", replace
    end

** Execute
main
    
    

    
    
