clear all
version 15
set more off

global main_pwd "/Users/deanli/Documents/GitHub/Nursing-Homes/dean_april_ownership_pass"
global derived_data "/Users/deanli/Dropbox (Personal)/Nursing Homes/Data/2022 Oct Ownership/derived"
global dropbox_data "/Users/deanli/Dropbox (Personal)/Nursing Homes/Data/Staffing Data/PBJ Nurse Staffing Quarterly"


program main
	save_mds_numbers
	large_group_count
	large_group_mds
	main_chow_acquirer
	new_analysis
end

	program save_mds_numbers
		import delim "${dropbox_data}/Payroll_Based_Journal_Daily_Nurse_Staffing_2022_Q3.csv", clear
		collapse (sum) mdscensus, by(provnum provname)
		rename provnum ccn
		cd "${main_pwd}"
		save "./temp/state_q3_2022", replace
	end

	program large_group_count
        cd "${derived_data}"
        use "./oct_enrollment.dta", clear
		cd "${main_pwd}"
		merge 1:1 ccn using ./temp/state_q3_2022, keepusing(mdscensus) keep(3) nogen

        qui count
        local total_count = `r(N)'

        replace affiliationentityid = 0 if missing(affiliationentityid)
        replace affiliationentityname = "None" if missing(affiliationentityname)

        gen count = 1
        collapse (sum) count, by(affiliationentityid state affiliationentityname)

        rename affiliationentityid large_group_id
        rename affiliationentityname large_group_name

        save "./temp/large_group_xw_state", replace
    end
	
	program large_group_mds
		cd "${derived_data}"
		use "./oct_enrollment.dta", clear
        cd "${main_pwd}"
        
		merge 1:1 ccn using ./temp/state_q3_2022, keepusing(mdscensus) keep(3) nogen
		rename affiliationentityid large_group_id
        rename affiliationentityname large_group_name
		
        keep enrollmentid state mdscensus large_group*
		save "./temp/large_group_census_state", replace
    end
	

	program main_chow_acquirer
		cd "${derived_data}"
		use "./sep_2022_chow.dta", clear
		cd "${main_pwd}"
		
		keep enrollmentidbuyer enrollmentstatebuyer 
		duplicates drop
		rename (enrollmentidbuyer enrollmentstatebuyer) (enrollmentid state)
		merge 1:1 enrollmentid using "./temp/large_group_census_state", keep(3) nogen

		gen count = 1
		collapse (sum) count mdscensus, by(large_group_id large_group_name state)
		
		rename count num_nh
		rename mdscensus num_mds
		
		save "./temp/large_group_state_acq_xw", replace
	end
	
	
	program new_analysis
		cd "${derived_data}"
		use "./oct_enrollment.dta", clear
		cd "${main_pwd}"
        
		merge 1:1 ccn using ./temp/state_q3_2022, keepusing(mdscensus) keep(3) nogen

		gen any_nh = 1 
		collapse (sum) any_nh mdscensus, by(state affiliationentityname)
		egen total_nh = sum(any_nh), by(state)
		egen total_census = sum(mdscensus), by(state)
		drop if affiliationentityname == ""
		
		
		gen share_nh_state = any_nh / total_nh
		gen share_mds_state = mdscensus / total_census
		rename affiliationentityname large_group_name
		
		
		merge 1:1 large_group_name state using "./temp/large_group_state_acq_xw", keep(1 3) nogen
		
		replace num_nh = 0 if missing(num_nh)
		replace num_mds = 0 if missing(num_mds)
		
		drop large_group_id
		
		gen pre_acq_count_homes = any_nh - num_nh
		gen pre_share_nh_state = pre_acq_count_homes / total_nh
		
		gen pre_count_mds = mdscensus - num_mds 
		gen pre_share_mds_state = pre_count_mds / total_census
	
		rename any_nh count_homes
		rename mdscensus count_mds
		
		rename total_nh state_homes
		rename total_census state_mds
		
		rename num_nh acquired_homes
		rename num_mds acquired_mds
		
		label var large_group_name "Affiliation Entity Name (from CMS Online)"
		label var state "State Abbreviation"
		label var count_homes "Number of Nursing Homes Owned by Entity"
		label var count_mds "Number of Patient-Days in Homes Owned by Entity"
		label var state_homes "Number of Nursing Homes in State"
		label var state_mds "Number of Patient Days in Homes in State"
		label var share_nh_state "Share of NH owned by Entity in State"
		label var share_mds_state "Share of Patient Days in Entity NH in State"
		label var acquired_homes "Number of NH Acquired by Entity since Jan 1, 2016"
		label var acquired_mds "Number of Patient-Days in NH Acquired by Entity since Jan 1, 2016"
		label var pre_acq_count_homes "Number of NH Before Jan 1, 2016"
		label var pre_share_nh_state "Share of NH Before Jan 1, 2016"
		label var pre_count_mds "Number of Patient-Days Before Jan 1, 2016"
		label var pre_share_mds_state "Share of Patient-Days Before Jan 1, 2016"
		
		save "./output/state_file", replace
	end
	
** Execute
main
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	