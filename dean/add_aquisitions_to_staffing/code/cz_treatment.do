clear all
version 15
set more off
global outcomes "hrs_rn hrs_lpn hrs_cna total_staff mdscensus" 

program main
    foreach geo in "cz" "county" "state" {
        any_acquisition, geo(`geo')
        within_market_acquisitions, geo(`geo')
    }
end
  
    program any_acquisition
        syntax, geo(str)

        use "../temp/baseline_data", clear
        drop if missing(`geo')
        gen ever_had_acquisition = ~missing(acquisition_date)
        collapse (max) ever_had_acquisition, by(`geo')
        save ../temp/`geo'_any_acquisition_exposure, replace
    end

    program within_market_acquisitions
        syntax, geo(str)

            ** Construct changes in group presence
            use "../temp/baseline_data", clear
            keep large_group_id `geo' provnum date
            duplicates drop
            gen count = 1
            collapse (sum) count, by(large_group_id `geo' date)
            drop if missing(`geo')
            egen company_geo = group(large_group_id `geo')
            tsset company_geo date
            gen change_in_count = (count > count[_n - 1]) & (count[_n - 1] > 0) & (company_geo == company_geo[_n - 1])
            keep if change_in_count
            keep date large_group_id `geo'
            save ../temp/changes_in_`geo'_group, replace

        use "../temp/baseline_data", clear
        merge m:1 large_group_id `geo' date using ../temp/changes_in_`geo'_group, keep(3) nogen
        keep if date == acquisition_date
        keep `geo'
        duplicates drop
        save ../temp/`geo'_within_market_exposure, replace
    end


    program add_to_baseline
        use "../temp/baseline_data", clear
        foreach geo in "county" "cz" "state" {
            merge m:1 `geo' using ../temp/`geo'_any_acquisition_exposure, keep(3) nogen
            rename ever_had_acquisition `geo'_acq_ever

            merge m:1 `geo' using ../temp/`geo'_within_market_exposure, assert(1 3)
            replace _merge = (_merge == 3)
            rename _merge `geo'_within_acq_ever

            label var `geo'_acq_ever "Ever acquisition in `geo'"
            label var `geo'_within_acq_ever "Ever a within-market acquisition in `geo'"
        }

        save "../output/baseline_data", replace
    end

** Execute
main
    
    

    
    
