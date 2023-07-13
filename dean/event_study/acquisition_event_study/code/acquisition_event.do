clear all
version 15
set more off
global outcomes "mds share_rn share_lpn share_cna ratio_rn_staff ratio_rn_mds ratio_cna_staff ratio_cna_mds ratio_staff_mds" 

program main
    foreach geo in "state" "county" {
        foreach panel in "long" "short" {
            foreach outcome in ${outcomes} {
                baseline_event_study, geo(`geo') outcome(`outcome') panel(`panel')
            }
        }
    }
end
    
    program baseline_event_study
        syntax, geo(str) outcome(str) panel(str)

        qui use "../temp/baseline_data", clear
        replace `outcome' = log(`outcome')

            if "`panel'" != "long" {
                drop if date > 12
            }

        ** Difference out the NH fixed effect **
        qui gen prev_outcome = cond(date == 1, `outcome', .)
        qui egen prev_outcome_norm = max(prev_outcome), by(provnum)
        qui replace `outcome' = `outcome' - prev_outcome_norm
        qui drop if missing(`outcome')

            ** Keep Control
            preserve
            qui keep if missing(acquisition_date)
            qui merge m:1 large_group_set using "../temp/ever_acquirer", keep(1 3) keepusing(ever_acquirer) nogen
            qui keep if missing(ever_acquirer)
            qui collapse (mean) `outcome', by(`geo' date)
            qui rename `outcome' control_`outcome'
            qui save "../temp/counterfactual", replace
            restore

        qui keep if ~missing(acquisition_date)
        qui merge m:1 `geo' date using "../temp/counterfactual", keep(3) nogen
        qui gen outcome = `outcome' - control_`outcome'
        qui gen rel_quarter = date - acquisition_date
        qui egen rel_group = group(rel_quarter)

        ** Merge in treatment **
        qui keep if inrange(rel_quarter, -8, 8)

        reg outcome i.rel_group, robust

        cap qui gen coefficient = .
        cap qui gen standard_error = .
        qui levelsof rel_group
        foreach RQ in `r(levels)' {
            qui cap replace coefficient = _b[`RQ'.rel_group] if rel_group == `RQ'
            qui cap replace standard_error = _se[`RQ'.rel_group] if rel_group == `RQ'
        }
        
        qui collapse (mean) coefficient standard_error, by(rel_quarter)
        save ../output/`geo'_event_study_`outcome'_`panel', replace

    end
    
    
  
** Execute
main
    
    

    
    
    
    
    
    
    