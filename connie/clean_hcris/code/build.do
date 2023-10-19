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
    import_append
end

program import_append 
    forval yr = 1995/2010 {
        import delimited using "${hcris_data}SNFFY`yr'/SNF_`yr'_ALPHA.CSV", clear
    }
    forval yr = 2011/2022 {
        // get ccns
        import delimited using "${hcris_data}SNF10FY`yr'/SNF10_`yr'_ALPHA.CSV", clear
        keep if v2 == "S200001" & v3 == 400 & v4 == 200
        keep v1 v5
        rename (v1 v5) (id ccn)
        gen yr = `yr'
        gduplicates drop
        save ../temp/hcris_ccn_`yr'_xwalk, replace
    
        //clean s3 part 1
        import delimited using "${hcris_data}SNF10FY`yr'/SNF10_`yr'_NMRC.CSV", clear
        keep if v2 == "S300001" & v3 == 100
        drop v2 v3
        rename (v1 v4 v5) (id var val)
        keep if inlist(var, "02200", "02300")
        reshape wide val, i(id) j(var) string
        rename (val02200 val02300) (num_fte_paid num_fte_nonpaid)
        gen yr = `yr'
        save ../temp/payroll_wrkers_`yr', replace
        
        //clean s3 part 2
        import delimited using "${hcris_data}SNF10FY`yr'/SNF10_`yr'_NMRC.CSV", clear
        keep if v2 == "S300005" & inlist(v4, "00500", "00200") & inlist(v3, 100, 200, 300, 1400, 1500, 1600)
        replace v4 = "fringe" if v4 == "00200"
        replace v4 = "wage" if v4 == "00500"

        keep v1 v3 v5 v4
        rename (v1 v3 v4 v5) (id var type val)
        reshape wide val , i(id var) j(type) string
        reshape wide valfringe valwage, i(id) j(var) 
        rename (valwage100 valwage200 valwage300 valwage1400 valwage1500 valwage1600) (rn_wage lpn_wage cna_wage c_rn_wage c_lpn_wage c_cna_wage)
        rename (valfringe100 valfringe200 valfringe300 valfringe1400 valfringe1500 valfringe1600) (rn_fringe lpn_fringe cna_fringe c_rn_fringe c_lpn_fringe c_cna_fringe)
        gen yr = `yr'
        drop if mi(rn_wage) & mi(lpn_wage) & mi(cna_wage) & mi(c_rn_wage) & mi(c_lpn_wage) & mi(c_cna_wage) & mi(rn_fringe) & mi(lpn_fringe) & mi(cna_fringe) & mi(c_rn_fringe) & mi(c_lpn_fringe) & mi(c_cna_fringe)
        save ../temp/wage`yr', replace
    }
    clear
    forval yr = 2011/2022 { 
        append using ../temp/hcris_ccn_`yr'_xwalk
    }
    gduplicates drop
    save ../output/hcris_ccn_xwalk, replace
    clear
    forval yr = 2011/2022 { 
        append using ../temp/wage`yr'
    }
    merge m:1 id yr using ../output/hcris_ccn_xwalk, assert(1 2 3) keep(3) nogen
    bys  id: kj
    save ../output/nh_hcris_wages, replace

    clear
    forval yr = 2011/2022 { 
        append using ../temp/payroll_wrkers_`yr'
    }
    save ../output/payroll_wrkers, replace
end
main
