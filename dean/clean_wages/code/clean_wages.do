clear all
version 15
set more off

program main
    wages
end
    
	program wages
        use ../external/nh_hcris_wages, clear
        rename ccn provnum
        rename yr year

        ** 6244 provnum - years with duplicates: 5,209 provnums
        ** Out of 157,315 provnum - years, 15,409

        collapse (mean) rn_wage lpn_wage cna_wage, by(provnum year)

        forvalues year = 2011/2022 {
            foreach job in "rn" "lpn" "cna" {
                qui sum `job'_wage if year == `year', det
                replace `job'_wage = `r(p99)' if `job'_wage > `r(p99)' & ~missing(`job'_wage) & year == `year'
                replace `job'_wage = `r(p1)' if `job'_wage < `r(p1)' & ~missing(`job'_wage) & year == `year'
            }
        }


        label var provnum "The Medicare CCN"
        label var year "The fiscal year (starts October of year before)"
        label var rn_wage "Average RN wages at facility (winsorized at 99% for year)"
        label var lpn_wage "Average LPN wages at facility (winsorized at 99% for year)"
        label var cna_wage "Average CNA wages at facility (winsorized at 99% for year)"
        save ../output/provnum_year_wage_xw, replace
    end
