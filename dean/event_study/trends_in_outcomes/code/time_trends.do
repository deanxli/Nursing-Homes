clear all
version 15
set more off
global outcomes "mds share_rn share_lpn share_cna ratio_rn_staff ratio_rn_mds ratio_cna_staff ratio_cna_mds ratio_staff_mds" 

program main

    foreach weight in "weighted" "unweighted" {
        foreach outcome in ${outcomes} {
            * time_trends_three, outcome(`outcome') weight(`weight')
        }
    }
end

program time_trends_three
    syntax, outcome(str) weight(str)

    use ../external/baseline_data, clear
    replace ever_acquirer = 0 if missing(ever_acquirer)
    egen ever_acquired = max(ever_acquirer), by(provnum)
    gen acq_status = cond(~missing(acquisition_date), 2, cond(ever_acquired, 1, 0))
    
    if "`weight'" == "weighted" {
        collapse (mean) `outcome' [aw=mds], by(acq_status date)
        local weight_text " (Weighted by Size)"
    }
    else {
        collapse (mean) `outcome', by(acq_status date)
    }

        if inlist("`outcome'", "share_rn") {
            local ytitle "Mean Share of RN Hours Outsourced`weight_text'"
        }

        else if inlist("`outcome'", "share_lpn") {
            local ytitle "Mean Share of LPN Hours Outsourced`weight_text'"
        }
        else if inlist("`outcome'", "share_cna") {
            local ytitle "Mean Share of CNA Hours Outsourced`weight_text'"
        }

        else if inlist("`outcome'", "mds") {
            local ytitle "Mean Patient-Days in Quarter`weight_text'"
        }

        else if inlist("`outcome'", "ratio_rn_staff") {
            local ytitle "Mean Ratio of RN - Staff Days`weight_text'"
        }

        else if inlist("`outcome'", "ratio_rn_mds") {
            local ytitle "Mean Ratio of RN - Patient Days`weight_text'"
        }
     
        else if inlist("`outcome'", "ratio_cna_staff") {
            local ytitle "Mean Ratio of CNA - Staff Days`weight_text'"
        }

        else if inlist("`outcome'", "ratio_cna_mds") {
            local ytitle "Mean Ratio of CNA - Patient Days`weight_text'"
        }

        else if inlist("`outcome'", "ratio_staff_mds") {
            local ytitle "Mean Ratio of Staff - Patient Days`weight_text'"
        }

    twoway (connected `outcome' date if acq_status == 0, ///
                mcolor(navy%70) msymbol(o) lcolor(navy%70) lpattern(dash) lwidth(medthin)) ///
           (connected `outcome' date if acq_status == 1, ///
                mcolor(maroon%70) msymbol(o) lcolor(maroon%70) lpattern(dash) lwidth(medthin)) ///
           (connected `outcome' date if acq_status == 2, ///
                mcolor(gs11%70) msymbol(o) lcolor(gs11%70) lpattern(dash) lwidth(medthin)), ///
            scheme(s1mono) xtitle("") ///
            xtick(1(1)22) xlabel(1 "Q1 2017" 5 "Q1 2018" 9 "Q1 2019" 13 "Q1 2020" 17 "Q1 2021" 21 "Q1 2022") ///      
            xline(13,lpattern(dash) lwidth(thin) lcolor(maroon)) ylabel(, angle(0) grid) ytitle("") ///
            subtitle("`ytitle'", position(11) justification(left) size(medium)) ///
            legend(order(1 "Never Owned by Acquirers" 2 "Always Owned by Acquirers" 3 "Acquired by Acquirers") col(1))

    graph export "../figures/three_trends_`outcome'_`weight'.pdf", replace
end
    
  
** Execute
main
    
    

    
    
    
    
    
    
    