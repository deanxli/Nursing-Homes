version 15
set more off

global file_path "/Users/deanli/Dropbox (Personal)/Nursing Homes/Data/Staffing Data/POS Yearly/"

program main
    * load_data
    * gen_share
    * gen_share_by_state
    gen_2005_2015
end

program load_data
    use "/Users/deanli/Dropbox (Personal)/Nursing Homes/Data/Staffing Data/POS Yearly/pos_database_nh.dta", clear

    keep facility_type staff_hrpbd category lic_waiver dual hosp_based npngov orgnl_prtcptn_dt facility_type fyear fips_cnty_cd prvdr_num fac_name city state zip_cd forprof govt bed lpn_lvn lpn_lvn_cnt nrs_aide nrs_aide_cnt rn rn_cntrct 
    rename fips_cnty_cd county
    duplicates drop
    save ../temp/working_file, replace
end 

program gen_share
    use ../temp/working_file, clear

    foreach outcome in "nrs_aide" "rn" "lpn_lvn" {
        gen share_`outcome' = `outcome'_cnt / `outcome'
        gen any_`outcome' = (share_`outcome' > 0) & ~missing(share_`outcome')
    }

    collapse (mean) share_* any_*, by(fyear)

    foreach outcome in "nrs_aide" "rn" "lpn_lvn" {
        twoway connected share_`outcome' fyear, ///
            xtitle(Year) ///
            scheme(s1mono) ylabel(, angle(0)) ytitle("") ///
            subtitle("Share of Contract Hours: `outcome'", position(11) justification(left) size(medium)) 
        graph export ../output/share_`outcome'.pdf, replace

        twoway connected any_`outcome' fyear, ///
            xtitle(Year) ///
            scheme(s1mono) ylabel(, angle(0)) ytitle("") ///
            subtitle("Share of Nursing Homes with Contract Hours: `outcome'", position(11) justification(left) size(medium)) 
        graph export ../output/any_`outcome'.pdf, replace
    }
end

program gen_share_by_state
    use ../temp/working_file, clear

    foreach outcome in "nrs_aide" "rn" "lpn_lvn" {
        gen share_`outcome' = `outcome'_cnt / `outcome'
        gen any_`outcome' = (share_`outcome' > 0) & ~missing(share_`outcome')
    }

    qui levelsof state
    foreach geo in `r(levels)' {

        preserve
        cap mkdir "../output/states/`geo'"
        keep if state == "`geo'"

        collapse (mean) share_* any_*, by(fyear state)
        foreach outcome in "nrs_aide" "rn" "lpn_lvn" {
            twoway connected share_`outcome' fyear, ///
                xtitle(Year) ///
                scheme(s1mono) ylabel(, angle(0)) ytitle("") ///
                subtitle("Share of Contract Hours: `outcome'", position(11) justification(left) size(medium)) 
            graph export ../output/states/`geo'/share_`outcome'.pdf, replace

            twoway connected any_`outcome' fyear, ///
                xtitle(Year) ///
                scheme(s1mono) ylabel(, angle(0)) ytitle("") ///
                subtitle("Share of Nursing Homes with Contract Hours: `outcome'", position(11) justification(left) size(medium)) 
            graph export ../output/states/`geo'/any_`outcome'.pdf, replace
        }
        restore
    }
end

program gen_2005_2015
    use ../temp/working_file, clear

    foreach outcome in "nrs_aide" "rn" "lpn_lvn" {
        gen share_`outcome' = `outcome'_cnt / `outcome'
        gen any_`outcome' = (share_`outcome' > 0) & ~missing(share_`outcome')
    }

    collapse (mean) share_* any_*, by(fyear state)
    drop if state == "PR"
    drop if state == "GU"
    drop if state == "VI"
    drop if state == "AK" 
    drop if state == "HI"


    foreach outcome in "nrs_aide" "rn" "lpn_lvn" {
            keep if inlist(fyear, 2005, 2015)

            local year 2015
            gen share_`outcome'_`year'_temp = cond(fyear == `year', share_`outcome', .)
            egen share_`outcome'_`year' = max(share_`outcome'_`year'_temp), by(state)

            local year 2005
            gen share_`outcome'_`year'_temp = cond(fyear == `year', share_`outcome', .)
            egen share_`outcome'_`year' = max(share_`outcome'_`year'_temp), by(state)

        twoway (scatter share_`outcome'_2015 share_`outcome'_2005, mlabel(state)) (line share_`outcome'_2015 share_`outcome'_2015, lcolor(red)), ///
            xtitle(Share of `outcome' Hours that were Contract: 2005) ///
            scheme(s1mono) ylabel(, angle(0)) ytitle("") legend(off) ///
            subtitle("Share of `outcome' Hours that were Contract: 2015", position(11) justification(left) size(medium)) 
        graph export ../output/2005_2015_share_`outcome'.pdf, replace
    }

end

program gen_change_by_share
    use ../temp/working_file, clear

    foreach outcome in "nrs_aide" "rn" "lpn_lvn" {
        gen share_`outcome' = `outcome'_cnt / `outcome'
        gen any_`outcome' = (share_`outcome' > 0) & ~missing(share_`outcome')
    }

    qui levelsof fyear
    foreach year in `r(levels)' {
        if `year' > 2000 {
            preserve


            collapse (mean) share_* any_*, by(fyear state)

            local year 2010
            local outcome nrs_aide
            cap mkdir "../output/states/`year'/"
            local prev_year = `year' - 1
            keep if inlist(fyear, `prev_year', `year')


            gen share_`outcome'_`year'_temp = cond(fyear == `year', share_`outcome', .)
            egen share_`outcome'_`year' = max(share_`outcome'_`year'_temp), by(state)


            gen share_`outcome'_`prev_year'_temp = cond(fyear == `prev_year', share_`outcome', .)
            egen share_`outcome'_`prev_year' = max(share_`outcome'_`prev_year'_temp), by(state)

            gen change_`outcome' = (share_`outcome'_`year' - share_`outcome'_`prev_year')
            keep state change_`outcome'
            duplicates drop
            drop if missing(change_`outcome')

            
            collapse (mean) share_* any_*, by(fyear state)
            foreach outcome in "nrs_aide" "rn" "lpn_lvn" {
                twoway connected share_`outcome' fyear, ///
                    xtitle(Year) ///
                    scheme(s1mono) ylabel(, angle(0)) ytitle("") ///
                    subtitle("Share of Contract Hours: `outcome'", position(11) justification(left) size(medium)) 
                graph export ../output/states/`year'/share_`outcome'.pdf, replace

                twoway connected any_`outcome' fyear, ///
                    xtitle(Year) ///
                    scheme(s1mono) ylabel(, angle(0)) ytitle("") ///
                    subtitle("Share of Nursing Homes with Contract Hours: `outcome'", position(11) justification(left) size(medium)) 
                graph export ../output/states/`geo'/any_`outcome'.pdf, replace
            }
            restore
        }
    }
end

* EXECUTE
main
