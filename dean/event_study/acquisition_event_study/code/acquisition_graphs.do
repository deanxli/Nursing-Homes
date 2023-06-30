clear all
version 15
set more off
global outcomes "mds share_rn share_lpn share_cna ratio_rn_staff ratio_rn_mds ratio_cna_staff ratio_cna_mds ratio_staff_mds" 

program main
    foreach geo in "cz" "state" "county" {
        foreach panel in "long" "short" {
            foreach outcome in ${outcomes} {
                gen_figure, geo(`geo') outcome(`outcome') panel(`panel')
            }
        }
    }
end
    
    program gen_figure
        syntax, geo(str) outcome(str) panel(str)

        if inlist("`outcome'", "share_rn") {
            local ytitle "Change in Log RN Outsourcing Rate"
            local ylines_short "0(.25)1.5"
            local ylines_long "-0.25(.25)0.5"
        }

        else if inlist("`outcome'", "share_lpn") {
            local ytitle "Change in Log LPN Outsourcing Rate"
            local ylines_short "-0.25(.25)2.0"
            local ylines_long "-0.25(.25).75"
        }
        else if inlist("`outcome'", "share_cna") {
            local ytitle "Change in Log CNA Outsourcing Rate"
            local ylines_short "-0.25(.25)1.25"
            local ylines_long "-0.25(.25)1"
        }

        else if inlist("`outcome'", "mds") {
            local ytitle "Change in Log Patient-Day Count"
            local ylines_short "-0.5(.5)2.0"
            local ylines_long "-0.25(.25)1.0"
        }

        else if inlist("`outcome'", "ratio_rn_staff") {
            local ytitle "Change in Log RN - Staff Ratio"
            local ylines_short "-0.5(.25)0.75"
            local ylines_long "-0.5(.25)0.75"
        }

        else if inlist("`outcome'", "ratio_rn_mds") {
            local ytitle "Change in Log RN - Patient Ratio"
            local ylines_short "-0.5(.25)1.0"
            local ylines_long "-0.25(.25)0.75"
        }
     
        else if inlist("`outcome'", "ratio_cna_staff") {
            local ytitle "Change in Log CNA - Staff Ratio"
            local ylines_short "-1(.5)1"
            local ylines_long "-0.5(.25)0.5"
        }

        else if inlist("`outcome'", "ratio_cna_mds") {
            local ytitle "Change in Log CNA - Patient Ratio"
            local ylines_short "-0.5(.5)2.0"
            local ylines_long "-0.25(.25)0.50"
        }

        else if inlist("`outcome'", "ratio_staff_mds") {
            local ytitle "Change in Log Staff - Patient Ratio"
            local ylines_short "-0.25(.25)1.5"
            local ylines_long "-0.25(.25)0.50"
        }

        else if inlist("`outcome'", "total_staff") {
            local ytitle "Change in Log Total Staff Days"
            local ylines_short "-0.25(.25)1.25"
            local ylines_long "-0.25(.25)0.50"
        }

        use ../output/`geo'_event_study_`outcome'_`panel', clear

        qui sum coefficient if rel_quarter < 0
        local mean_selection : di %3.1f `r(mean)' * 100
        replace coefficient = coefficient - `r(mean)'


        gen upper_ci = coefficient + 1.96 * standard_error
        gen lower_ci = coefficient - 1.96 * standard_error

        twoway (connected coefficient rel_quarter, msymbol(o) msize(medlarge) mcolor(black) lcolor(black) lpattern(solid)) ///
                (line lower_ci rel_quarter, ///
                    lpattern(dash) lcolor(maroon%50)) ///
                (line upper_ci rel_quarter, ///
                    lpattern(dash) lcolor(maroon%50)), ///
                xlabel(-8(2)8)  xtick(-8(1)8) legend(off) ///
                scheme(s1mono) xline(0,lwidth(7) lcolor(gs11)) ///
                xtitle("Quarter Relative to Acquisition") ///
                ylabel(, angle(0) grid) ytitle("") ///
                subtitle("`ytitle'", position(11) justification(left) size(medsmall))

        graph export "../figures/`geo'_`outcome'_`panel'.pdf", replace
    end
    
    
  
** Execute
main
    
    

    
    
    
    
    
    
    