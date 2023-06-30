clear all
version 15
set more off
global outcomes "hrs_rn hrs_lpn hrs_cna mds share_rn share_lpn share_cna ratio_rn_staff ratio_rn_mds ratio_cna_staff ratio_cna_mds ratio_staff_mds" 

program main
    construct_baseline
    merge_in_acquisitions
end
    
    
    program construct_baseline
        use "../external/master_quarterly_agg_dean.dta", clear
        
        gen total_staff = (hrs_rn + hrs_cna + hrs_lpn)   
        gen ratio_rn_staff = hrs_rn / total_staff
        gen ratio_rn_mds = hrs_rn / (mdscensus * 8)
        gen ratio_cna_staff = hrs_cna / total_staff
        gen ratio_cna_mds = hrs_cna / (mdscensus * 8)
        gen ratio_staff_mds = total_staff / (mdscensus * 8)
        replace total_staff = total_staff / 8

        keep provnum date state cz large_group_id ${outcomes}
        egen state_grp = group(state)
        egen large_group_set = group(large_group_id)

        save "../temp/baseline_file", replace
    end

    program merge_in_acquisitions
        acquirer_and_date
        ever_acquirer 
        non_acquired_provnum

        use "../temp/baseline_file", clear
        merge m:1 provnum using ../temp/acquisition_date_marker, keep(1 3) keepusing(acquirer_set prev_owner_set acquisition_date) nogen
        merge m:1 provnum using ../temp/alt_acquisition_date_marker, keep(1 3) keepusing(alt_acq_date) nogen
        merge m:1 large_group_set using ../temp/ever_acquirer, keep(1 3) keepusing(ever_acquirer) nogen
        save "../temp/baseline_data", replace
    end

            ** Save the acquirer, the date, and the previous owner
            program acquirer_and_date
                use "../temp/baseline_file", clear 
                keep provnum large_group_set large_group_id date
            
                    preserve
                    keep provnum large_group_set
                    duplicates drop
                    gen count = 1
                    collapse (sum) count, by(provnum)
                    keep if count > 1
                    save ../temp/chow, replace
                    restore

                merge m:1 provnum using "../temp/chow", keep(3) nogen
                drop count
                egen prov_group = group(provnum)
                tsset prov_group date

                gen prev_owner = large_group_set[_n - 1]
                gen prev_owner_id = large_group_id[_n - 1]
                gen acquisition = (large_group_set != prev_owner) & ~missing(prev_owner) & (provnum == provnum[_n - 1])
                keep if acquisition == 1
                
                egen acquisition_date = min(date), by(provnum)
                rename large_group_id acquirer_id
                rename large_group_set acquirer_set
                rename prev_owner prev_owner_set
                keep provnum acquisition_date acquirer_set acquirer_id prev_owner_set prev_owner_id
                save "../temp/acquisition_date_marker", replace
            end

            program ever_acquirer
                use "../temp/acquisition_date_marker", clear
                keep acquirer_set acquirer_id
                duplicates drop

                gen ever_acquirer = 1
                rename acquirer_* large_group_*
                save "../temp/ever_acquirer", replace
            end

            program non_acquired_provnum    
                use "../external/sep_2022_chow.dta", clear 
                gen year = substr(effectivedate, 7, 4)
                gen month = substr(effectivedate, 1, 2)
                
                destring year, replace
                destring month, replace
                
                gen date = (year - 2017) * 4 + floor((month - 1) / 3)
                keep ccnbuyer date
                rename ccnbuyer provnum
                rename date alt_acq_date
                save "../temp/alt_acquisition_date_marker", replace
            end
    
** Execute
main
    
    

    
    
    
    
    
    
    