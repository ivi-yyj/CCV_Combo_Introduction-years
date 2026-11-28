
import excel "C:\Desktop\Data", firstrow clear

expand 15
bysort Country: gen year = 2010 + _n

preserve

    import delimited "IHME-GBD_2023_DATA-bffddf47-1.csv", clear

    keep if cause_name == "Diarrheal diseases" 
    rename location_name COUNTRYNAME

    merge m:1 COUNTRYNAME using "cty_gavi_income.dta"
    keep if _merge == 3 & year >= 2011

    keep COUNTRYNAME ISO GaviStatus CurrentGaviEligibility WorldBankIncomeGroup year val

    rename COUNTRYNAME Country
    rename val dalys

    tempfile temp_comp1
    save `temp_comp1'

restore

merge m:m ISO year using `temp_comp1', keepusing(dalys)
drop if _merge == 2
drop _merge

preserve

    use "WHO_coverage_data.dta", clear

    rename CODE ISO
    merge m:1 ISO using "cty_gavi_income.dta"

    keep if _merge == 3
    keep if inlist(ANTIGEN_DESCRIPTION, ///
        "Measles-containing vaccine, 1st dose", ///
        "Measles-containing vaccine, 2nd dose")

    collapse (min) COVERAGEWUENIC, ///
        by(ISO COUNTRYNAME YEAR GaviStatus CurrentGaviEligibility WorldBankIncomeGroup)

    rename COVERAGEWUENIC coverage_mcv
    rename COUNTRYNAME Country
    rename YEAR year

    tempfile temp_coverage
    save `temp_coverage'

restore

merge m:m ISO year using `temp_coverage', ///
    nogenerate keepusing(coverage_mcv)
drop if Country == ""


preserve

    import delimited "Population_WB_WDI_SP_POP_TOTL_WIDEF.csv", clear

    rename ref_area_label Country
    rename ref_area ISO

    keep Country ISO v93-v106
    reshape long v, i(Country ISO) j(year)

    replace year = year + 1918
    rename v pop_wb

    tempfile temp_pop
    save `temp_pop'

restore

merge m:m ISO year using `temp_pop', keepusing(pop_wb)
drop if _merge == 2
drop _merge
drop if Country == ""


preserve

    import excel "WPP2024_POP_F01_1_POPULATION_SINGLE_AGE_BOTH_SEXES_re.xlsx", ///
        sheet("Estimates") firstrow clear

    foreach var of varlist L-DH {
        destring `var', replace force
    }

    egen pop = rowtotal(L-DH)
    gen pop_un = pop * 1000

    rename Regionsubregioncountryorar Country
    rename ISO3Alphacode ISO
    rename Year year

    keep Country ISO year pop_un

    tempfile temp_pop_un
    save `temp_pop_un'

restore

merge m:m ISO year using `temp_pop_un', keepusing(pop_un)
drop if _merge == 2
drop _merge


preserve

    import excel "WPP2024_POP_F01_1_POPULATION_SINGLE_AGE_BOTH_SEXES_re.xlsx", ///
        sheet("Medium variant") firstrow clear

    foreach var of varlist L-DH {
        destring `var', replace force
    }

    egen pop = rowtotal(L-DH)
    gen pop_un_est = pop * 1000

    rename Regionsubregioncountryorar Country
    rename ISO3Alphacode ISO
    rename Year year

    keep Country ISO year pop_un_est

    save "un_pop_est.dta", replace

restore


preserve

    import excel "CLASS_2025_10_07.xlsx", ///
        sheet("List of economies") firstrow clear

    drop if Region == ""

    rename Code ISO
    rename Region geopolitical_region
    rename Incomegroup wb_incomegrp

    tempfile temp_georegion
    save `temp_georegion'

restore

merge m:1 ISO using `temp_georegion', ///
    keepusing(geopolitical_region wb_incomegrp)

drop if _merge == 2
drop _merge


preserve

    import excel "un-agencies-region-classification-for-country.xlsx", firstrow clear

    drop if WHORegionname2 == ""

    rename ISOCountrycode ISO
    rename WHORegionname2 who_region
    rename UNSDCountryname Country

    tempfile temp_whoregion
    save `temp_whoregion'

restore

merge m:1 ISO using `temp_whoregion', keepusing(who_region)
drop if _merge == 2
drop _merge

tab geopolitical_region, missing
tab who_region, missing


preserve

    use "WHO_coverage_data.dta", clear

    rename CODE ISO
    merge m:1 ISO using "cty_gavi_income.dta"

    keep if _merge == 3
    keep if ANTIGEN_DESCRIPTION == "DTP-containing vaccine, 3rd dose"
    keep if YEAR >= 2011

    collapse (min) COVERAGEWUENIC, ///
        by(ISO COUNTRYNAME YEAR GaviStatus CurrentGaviEligibility WorldBankIncomeGroup)

    rename COVERAGEWUENIC coverage_dtp3
    rename COUNTRYNAME Country
    rename YEAR year

    tempfile temp_coverage_dtp3
    save `temp_coverage_dtp3'

restore

merge m:m ISO year using `temp_coverage_dtp3', ///
    nogenerate keepusing(coverage_dtp3)

drop if Country == ""


preserve

    import delimited "EIU_DI_WIDEF.csv", clear

    drop if inlist(ref_area, "142", "3", "150", "5", "2", "9") | ///
        inlist(ref_area, "002", "003", "005", "009", "WLD")

    rename ref_area_label Country
    rename ref_area ISO

    keep Country ISO v43-v56
    reshape long v, i(ISO Country) j(year)

    replace year = year + 1968
    rename v demo_score

    save "survival_scoring_v1_temp_demo.dta", replace

restore


preserve

    import excel "API_NY.GNP.PCAP.CD_DS2_en_excel_v2_463_re.xlsx", ///
        sheet("Data") firstrow clear

    drop if Country == ""
    keep Country ISO BD-BR

    rename (BD BE BF BG BH BI BJ BK BL BM BN BO BP BQ BR) ///
           (yr2011 yr2012 yr2013 yr2014 yr2015 yr2016 yr2017 yr2018 ///
            yr2019 yr2020 yr2021 yr2022 yr2023 yr2024 yr2025)

    reshape long yr, i(ISO Country) j(year)
    rename yr gni

    save "survival_scoring_v1_temp_gni.dta", replace

restore

merge m:m ISO year using "survival_scoring_v1_temp_gni.dta", ///
    keepusing(gni)

drop if _merge == 2
drop _merge



use "C:\Desktop\Data\dta", clear

preserve 
sort www_final_score_2

gen rank = _n

gen barrier_y = 1 + 0.04*(3 - www_final_score_2_q) ///
    if inlist(www_final_score_2_q, 1, 2, 3)

local low_color      emerald
local moderate_color sand
local high_color     maroon

twoway ///
    (scatter barrier_y rank if www_final_score_2_q == 1, ///
        msymbol(O) ///
        msize(0) ///
        mcolor(`low_color') ///
        mlabel(Country) ///
        mlabcolor(`low_color') ///
        mlabsize(medsmall) ///
        mlabposition(12) ///
        mlabgap(*2.5) ///
        mlabangle(45) ///
    ) ///
    (scatter barrier_y rank if www_final_score_2_q == 2, ///
        msymbol(O) ///
        msize(0) ///
        mcolor(`moderate_color') ///
        mlabel(Country) ///
        mlabcolor(`moderate_color') ///
        mlabsize(medsmall) ///
        mlabposition(12) ///
        mlabgap(*2.5) ///
        mlabangle(45) ///
    ) ///
    (scatter barrier_y rank if www_final_score_2_q == 3, ///
        msymbol(O) ///
        msize(0) ///
        mcolor(`high_color') ///
        mlabel(Country) ///
        mlabcolor(`high_color') ///
        mlabsize(medsmall) ///
        mlabposition(12) ///
        mlabgap(*2.5) ///
        mlabangle(45) ///
    ), ///
    ylabel( ///
        1.00 "{bf:High-Barriers}" ///
        1.04 "{bf:Moderate-Barriers}" ///
        1.08 "{bf:Low-Barriers}", ///
        labsize(medsmall) ///
        notick ///
        angle(0) ///
    ) ///
    yscale(range(0.985 1.12)) ///
    xscale(range(0 40)) ///
    xlabel(none) ///
    xtitle("") ///
    ytitle("") ///
    title("{bf:EPI integration}") ///
    legend(off) ///
    plotregion( ///
        margin(l=2 r=12 t=4 b=6) ///
    ) ///
    graphregion( ///
        color(white) ///
        margin(l=3 r=8 t=3 b=5) ///
    ) ///
    ysize(2.5) ///
    xsize(5.5)

restore


preserve

sort adjusted_T_rescale

gen rank = _n
gen zero = 0

local xlab ""
quietly levelsof rank, local(ranks)

foreach r of local ranks {
    quietly levelsof Country if rank==`r', local(cname) clean
    local xlab `"`xlab' `r' "`cname'""'
}

local marker_options ///
    msymbol(circle) ///
    msize(medium) ///
    mlabel(adjusted_T_rescale) ///
    mlabformat(%4.1f) ///
    mlabsize(tiny) ///
    mlabposition(12)

twoway ///
    (rspike zero adjusted_T_rescale rank ///
        if www_final_score_2_q == 1, ///
        lcolor(emerald) ///
        lwidth(thin)) ///
    (rspike zero adjusted_T_rescale rank ///
        if www_final_score_2_q == 2, ///
        lcolor(sand) ///
        lwidth(thin)) ///
    (rspike zero adjusted_T_rescale rank ///
        if www_final_score_2_q == 3, ///
        lcolor(maroon) ///
        lwidth(thin)) ///
    (scatter adjusted_T_rescale rank ///
        if www_final_score_2_q == 1, ///
        `marker_options' ///
        mcolor(emerald) ///
        mlabcolor(emerald)) ///
    (scatter adjusted_T_rescale rank ///
        if www_final_score_2_q == 2, ///
        `marker_options' ///
        mcolor(sand) ///
        mlabcolor(sand)) ///
    (scatter adjusted_T_rescale rank ///
        if www_final_score_2_q == 3, ///
        `marker_options' ///
        mcolor(maroon) ///
        mlabcolor(maroon)), ///
    xlabel(`xlab', ///
        angle(45) ///
        labsize(vsmall) ///
        notick) ///
    ylabel(0(5)15, ///
        labsize(small) ///
        glpattern(dash) ///
        glwidth(vthin) ///
        glcolor(gs14)) ///
    yscale(range(0 15)) ///
    xtitle("") ///
    ytitle("{bf:Estimated Time (Year)}", ///
        size(small) ///
        margin(r=2)) ///
    title("{bf:CCV - Introduction years by country}", ///
        size(medsmall) ///
        justification(center)) ///
    legend( ///
        order(4 "Low-Barriers" ///
              5 "Moderate-Barriers" ///
              6 "High-Barriers") ///
        rows(1) ///
        size(vsmall) ///
        position(6) ///
        title("{bf:EPI integration: }", ///
            size(vsmall) ///
            color(black) ///
            position(9) ///
            ring(1)) ///
    ) ///
    scheme(s2color) ///
    graphregion(color(white)) ///
    plotregion( ///
        color(white) ///
        margin(b=0))
restore


preserve
gen ccv_intro_year = 2034 + adjusted_T_rescale

gen combo_estimated_T_4 = .

replace combo_estimated_T_4 = ccv_intro_year ///
    if ccv_intro_year < 2037

replace combo_estimated_T_4 = ccv_intro_year + adjust_yr_4_only ///
    if ccv_intro_year >= 2037 & adjust_yr_4_only != 5

replace combo_estimated_T_4 = ccv_intro_year ///
    if adjust_yr_4_only == 5

gen combo_estimated_T_4a = 2036 + adjust_yr_4 ///
    if ccv_intro_year < 2037 & adjust_yr_4 != 5

gen combo_estimated_T_4b = combo_estimated_T_4

replace combo_estimated_T_4b = combo_estimated_T_4a ///
    if combo_estimated_T_4a != .

replace combo_estimated_T_4b = . ///
    if combo_estimated_T_4b == ccv_intro_year & adjust_yr_4_only == 5

sort ccv_intro_year Country

gen order = _n
labmask order, values(Country)

gen shade_lo = .
gen shade_hi = .
gen shade_x  = .

replace shade_lo = 0.5 in 1/2
replace shade_hi = _N in 1/2

replace shade_x = 2036 in 1
replace shade_x = 2036.9 in 2

label values shade_lo order
label values shade_hi order

#delimit ;

twoway
    (rarea shade_lo shade_hi shade_x,
        color(gs14%50)
        lwidth(none))

    (rcap ccv_intro_year combo_estimated_T_4b order,
        horizontal
        lcolor(gs11)
        lwidth(medium))

    (scatter order ccv_intro_year,
        msymbol(circle)
        msize(medium)
        mcolor(stc1)
        mlcolor(white)
        mlwidth(thin))

    (scatter order ccv_intro_year
        if ccv_intro_year >= 2037 & combo_estimated_T_4b != .,
        msymbol(circle)
        msize(medium)
        mcolor(white)
        mlcolor(stc1)
        mlwidth(thin))

    (scatter order combo_estimated_T_4b,
        msymbol(circle)
        msize(medium)
        mcolor(orange_red)
        mlcolor(white)
        mlwidth(thin)),

    ylabel(1(1)`=_N',
        valuelabel
        angle(0)
        labsize(vsmall))

    yscale(reverse)
    ytitle("")

    xlabel(2034(2)2047,
        labsize(vsmall))

    xtitle("Introduction year",
        size(small))

    text(37 2036.5
        "TCV/CCV"
        "WHO PQ (2036)",
        placement(c)
        size(vsmall)
        color(gs6))

    legend(
        order(3 "CCV"
              4 "CCV replaced with TCV/CCV"
              5 "TCV/CCV")
        position(6)
        rows(1)
        region(lcolor(black))
        size(vsmall)
        ring(1))

    title("{bf:CCV vs TCV/CCV introduction year by country}",
        size(small)
        span
        position(1))

    note("The shaded band indicates the WHO PQ window for TCV/CCV during 2036.",
        size(vsmall))
restore


preserve 

gen censored = inlist(Country, ///
    "Iran", ///
    "Philippines", ///
    "Burundi")

replace time_date = td(01jun2026) if censored

sort time_date

gen rank = _n
gen zero = 0

gen time_count_yr = (time_date - td(01sep2011)) / 365.25
gen lbl_time = string(time_count_yr, "%4.1f")

local xlab ""
quietly levelsof rank, local(ranks)

foreach r of local ranks {
    quietly levelsof Country if rank == `r', ///
        local(cname) clean

    local xlab `"`xlab' `r' "`cname'""'
}

quietly summarize time_count_yr if Country == "South Sudan", meanonly

local xpos = r(min) + 2.2
local text_x = `xpos' + 3.2

twoway ///
    (pcspike zero rank time_count_yr rank, ///
        lcolor(purple) ///
        lwidth(thin)) ///
    (scatter time_count_yr rank if !censored, ///
        msymbol(circle) ///
        mcolor(purple) ///
        msize(medium) ///
        mlabel(lbl_time) ///
        mlabcolor(purple) ///
        mlabsize(vsmall) ///
        mlabposition(12) ///
        mlabangle(0)), ///
    xlabel(`xlab', ///
        angle(45) ///
        labsize(vsmall) ///
        notick ///
        glcolor(white)) ///
    ylabel(0(5)15, ///
        format(%4.0f) ///
        labsize(small) ///
        glpattern(dash) ///
        glwidth(vthin) ///
        glcolor(gs14)) ///
    xline(`xpos', ///
        lcolor(teal) ///
        lpattern(shortdash) ///
        lwidth(medthick)) ///
    text(14 `text_x' ///
        "OCV stockpile establishment" ///
        "(July 2013)", ///
        size(2.5) ///
        color(teal)) ///
    xtitle("") ///
    ytitle("{bf:Observed time to OCV introduction (Year)}", ///
        size(small)) ///
    title("", ///
        size(medsmall) ///
        justification(center)) ///
    legend(off) ///
    scheme(s2color) ///
    xsize(9) ///
    ysize(4) ///
    graphregion(color(white)) ///
    plotregion( ///
        color(white) ///
        margin(b=0))
restore