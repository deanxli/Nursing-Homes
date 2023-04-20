set more off
clear all
capture log close
program drop _all
set scheme modern
preliminaries
version 17
set maxvar 120000, perm

program main   
    import_append
end

program import_append 
    forval yr = 2011/2022 {
        // get ccns
        import delimited using "../external/samp/SNF10FY`yr'/SNF10_`yr'_ALPHA.CSV", clear
        keep if v2 == "S200001" & v3 == 400 & v4 == 200
        keep v1 v5
        rename (v1 v5) (id ccn)
        gen yr = `yr'
        gduplicates drop
        save ../temp/hcris_ccn_`yr'_xwalk, replace
    
        //clean s3 part 1
        import delimited using "../external/samp/SNF10FY`yr'/SNF10_`yr'_NMRC.CSV", clear
        keep if v2 == "S300001" & v3 == 100
        drop v2 v3
        rename (v1 v4 v5) (id var val)
        keep if inlist(var, "02200", "02300")
        reshape wide val, i(id) j(var) string
        rename (val02200 val02300) (num_fte_paid num_fte_nonpaid)
        gen yr = `yr'
        save ../temp/payroll_wrkers_`yr', replace
        
        //clean s3 part 2
        import delimited using "../external/samp/SNF10FY`yr'/SNF10_`yr'_NMRC.CSV", clear
        keep if v2 == "S300005" & v4 == "00500" & inlist(v3, 100, 200, 300, 1400, 1500, 1600)
        keep v1 v3 v5
        rename (v1 v3 v5) (id var val)
        reshape wide val, i(id) j(var) 
        rename (val100 val200 val300 val1400 val1500 val1600) (rn_wage lpn_wage cna_wage c_rn_wage c_lpn_wage c_cna_wage)
        gen yr = `yr'
        save ../temp/wage`yr', replace
    }
    clear
    forval yr = 2011/2022 { 
        append using ../temp/hcris_ccn_`yr'_xwalk
    }
    gduplicates drop
    save ../output/hcris_ccn_xwalk, replace
    forval yr = 2011/2022 { 
        append using ../temp/wage`yr'
    }
    merge m:1 id yr using ../output/hcris_ccn_xwalk, assert(1 2 3) keep(3) nogen
    save ../output/nh_hcris_wages, replace

    clear
    forval yr = 2011/2022 { 
        append using ../temp/payroll_wrkers_`yr'
    }
    save ../output/payroll_wrkers, replace
end
main
