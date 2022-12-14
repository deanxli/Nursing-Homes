set more off
clear all
capture log close
program drop _all
set scheme modern
preliminaries
version 17
set maxvar 120000, perm

program main   
    prep_xwalk
    prep_data
    create_maps
end

program prep_xwalk
    use "../external/geo/zip_zipc_cty_cz_crswlk.dta", clear
    gcontract zip cty
    gduplicates drop zip, force
    drop _freq
    gen zip5 = string(zip, "%05.0f")
    drop zip 
    rename zip5 zip
    save ../temp/zip_cnty, replace

    use "../external/geo/zip_zipc_cty_cz_crswlk.dta", clear
    gcontract zip cz1
    gduplicates drop zip, force
    drop _freq
    gen zip5 = string(zip, "%05.0f")
    drop zip
    rename zip5 zip
    save ../temp/zip_cz, replace
end
program prep_data 
    import delimited using "../external/samp/SNF_Enrollments_Oct_2022.csv", varnames(1) stringc(23) clear
    gen affiliation = affiliationentityname 
    replace affiliation = organizationname if mi(affiliation)
    egen affil_group = group(affiliation)
    rename zipcode zip
    replace zip = substr(zip,1,5)
    
    merge m:1 zip using ../temp/zip_cnty, assert(1 2 3) keep (1 3) nogen
    merge m:1 zip using ../temp/zip_cz, assert(1 2 3) keep (1 3) nogen

    foreach loc in zip city cty cz1 { 
        bys `loc' affil_group npi: gen owner_`loc'_counter = _n == 1
        bys `loc' : egen tot_owners_`loc' = total(owner_`loc'_counter)
        bys affil_group `loc': egen tot_nh_owner_`loc' = total(owner_`loc'_counter)
        gen `loc'_mkt_shr = tot_nh_owner_`loc'/tot_owners_`loc'
        bys `loc' : gen `loc'_id = _n == 1
        bys affil_group `loc': gen owner_`loc'_id = _n == 1
        gen hhi_`loc'_temp = (`loc'_mkt_shr * 100)^2 if owner_`loc'_id == 1
        bys `loc': egen hhi_`loc' = total(hhi_`loc'_temp)

        bys `loc' npi: gen nh_counter_`loc' = _n == 1
        bys `loc': egen tot_nhs_`loc' = total(nh_counter_`loc')
    }
    sum tot_nhs_cz1 if cz1_id == 1
    sum tot_nhs_cty if cty_id == 1
end

program create_maps
    preserve
    gcontract tot_nhs_cty cty
    rename cty county
    maptile tot_nhs_cty, geo(county1990)
    graph export ../output/figures/county.eps, replace
    restore

     preserve
    gcontract tot_nhs_cz1 cz1
    rename cz1 cz
    maptile tot_nhs_cz1, geo(cz1990)
    graph export ../output/figures/cz.eps, replace
    restore



end
main
