* Project:      MA Thesis
* Content:      Health outcomes
* Data:         Fragile families
* Author:       Michelle Rosenberger
* Date:         November 7, 2018

********************************************************************************
*********************************** PREAMBLE ***********************************
********************************************************************************
capture log close
clear all
est clear
set more off
set emptycells drop
set matsize 10000
set maxvar 10000

* Set working directories
if "`c(username)'" == "michellerosenberger"  {
    global USERPATH     "~/Development/MA"
}

global CLEANDATADIR  	"${USERPATH}/data/clean"
global TEMPDATADIR  	"${USERPATH}/data/temp"
global CODEDIR          "${USERPATH}/code"
global TABLEDIR         "${USERPATH}/output/tables"

* log

********************************************************************************
********************************** Regressions *********************************
********************************************************************************

* Health variables
use "${TEMPDATADIR}/health.dta", clear
rename idnum id

* Demographics
merge 1:1 id wave using "${TEMPDATADIR}/household_FF.dta"
keep if _merge == 3
drop _merge


/* -------------------------------- HEALTH ---------------------------------- */
* Youth health (parent-reported) observed each wave
foreach num of numlist 0 1 3 5 9 15 {
	gen chHealth_`num'_temp = chHealth if wave == `num'
	sum chHealth_`num'_temp
	egen chHealth_`num' = max(chHealth_`num'_temp), by(id)
}
/* ----------------------------------  END ---------------------------------- */



/* ------------------------------ ELIGIBILITY ------------------------------- */
* Eligibility observed for each wave

* Total eligibility
/* ----------------------------------  END ---------------------------------- */



/* ------------------------- SIMULATED ELIGIBILITY -------------------------- */
* Simulated eligibility observed for each wave

* Total simulated eligibility
/* ----------------------------------  END ---------------------------------- */



/* -------------------------------- COVERAGE -------------------------------- */
* Coverage observed for each wave
foreach num of numlist 0 1 3 5 9 15 {
	gen mediCov_c`num' = chMediHI if wave == `num'
	sum mediCov_c`num'
	label var mediCov_c`num' "Medicaid coverage youth (parent-reported) - Wave `num'"
}

* Total coverage
foreach num of numlist 0 1 3 5 9 15 {
	egen mediCov_t`num' = total(chMediHI) if wave <= `num', by(id)
	sum mediCov_t`num'
	label var mediCov_t`num' "Medicaid coverage youth (parent-reported) - Total until wave `num'"
}
drop *_temp
/* ----------------------------------  END ---------------------------------- */



/* ------------------------------ FACTOR SCORE ------------------------------ */
* A factor score variable I can leverage the correlation across the observations
/* Manual: the output will be easier to interpret if we display standardized
values for paths rather than path coefficients. A standardized value is in
standard deviation units. It is the change in one variable given a change in
another, both measured in standard deviation units. We can obtain standardized
values by specifying sem’s standardized option, which we can do when we fit
the model or when we replay results.

The standardized coefficients for this model can be interpreted as the
correlation coefficients between the indicator and the latent variable
because each indicator measures only one factor. For instance, the standardized
path coefficient a1<-Affective is 0.90, meaning the correlation between a1 and
Affective is 0.90. */

/* FACTOR SCORES
1. General factor score that includes all variables and the predicts factor
score at each age / wave
2. Construct a factor score for each age / wave */


* RECODE such that a higher score represents better health
global RECODEVARS anemia seizures foodDigestive eczemaSkin diarrheaColitis ///
headachesMigraines earInfection asthmaAttack limit

foreach var of global RECODEVARS {
	recode `var' 0=1 1=0
}
label define NOYES 0 "Yes" 1 "No"
label values ${RECODEVARS} NOYES

recode chHealth 1=5 2=4 3=3 5=1 4=2
recode moHealth 1=5 2=4 3=3 5=1 4=2

label define chHealth_neg 1 "Poor" 2 "Fair" 3 "Good" 4 "Very good" 5 "Excellent"
label values chHealth moHealth chHealth_neg

* FACTOR SCORE: GENERAL HEALTH - INCLUDES ALL THE VARIABLES
sem (Health -> chHealth anemia seizures foodDigestive eczemaSkin diarrheaColitis headachesMigraines earInfection asthmaAttack limit), method(mlmv) var(Health@1) standardized
foreach num of numlist 0 1 3 5 9 15 {
	predict healthFactor_a`num' if ( e(sample) == 1 & wave == `num' ), latent(Health)
}
predict healthFactor_all if e(sample) == 1, latent(Health)

foreach num of numlist 0 1 3 5 9 15 {
	sum healthFactor_a`num'
}
sum healthFactor_all
* histogram healthFactor_all

* Standardize healthFactor
foreach var in healthFactor_a {
	foreach wave of numlist 0 1 3 5 9 15 {
		egen `var'`wave'_std = std(`var'`wave')
	}
}

egen healthFactor_all_std = std(healthFactor_all)

* FACTOR SCORE: GENERAL HEALTH - SPECIFIC FOR EACH AGE
sem (Health -> chHealth feverRespiratory anemia seizures foodDigestive  eczemaSkin diarrheaColitis headachesMigraines earInfection) if wave == 9, method(mlmv) var(Health@1) standardized
predict healthFactor_e9 if ( e(sample) == 1 & wave == 9 ), latent(Health)

sem (Health -> chHealth foodDigestive eczemaSkin diarrheaColitis headachesMigraines earInfection limit) if wave == 15, method(mlmv) var(Health@1) standardized
predict healthFactor_e15 if ( e(sample) == 1 & wave == 15 ), latent(Health)




* Create binary index

* FACTOR SCORE: BEHAVIORAL QUESTIONS
* activity30 everSmoke everDrink



* FACTOR SCORE: DOCTOR VISISTS / MEDICAL EXPENDITURE
* medication

/* ----------------------------------  END ---------------------------------- */



/* ---------------------------- POWER CALULATION ---------------------------- */
* Mean and standard deviation from healthFactor_a15 
* N = 3500 and ratio Ntreat / Ncontrol = 2.33
power twomeans 0.1055147, sd(0.7533586) power(0.8) n(3500) nratio(2.33) // 0.0779

* egen zhealthFactor_a15 = std(healthFactor_a15)

di (0.975 + 0.843) * ((1/(0.7*0.3))^0.5) * (0.7533586/3500)^0.5 // 0.05820377

/* ----------------------------------  END ---------------------------------- */


/* ------------------------------- REGRESSIONS ------------------------------ */
global CONTROLS age female moEduc moAge avgInc moHealth

reg chHealth 			mediCov_c15 ${CONTROLS} if wave == 15, robust
est store chHealth_15_fifteen
estadd local Controls 		"$\checkmark$"	// add checkmark "Controls"

* Current
/* reg healthFactor_a15 	mediCov_c15 ${CONTROLS}
est store healthFactor_a15_mediCov_c15
estadd local Controls 		"$\checkmark$"	// add checkmark "Controls" */

reg healthFactor_a15_std 	mediCov_c15 ${CONTROLS} if wave == 15, robust
est store healthFactor_a15_fifteen
estadd local Controls 		"$\checkmark$"	// add checkmark "Controls"

reg medication 			mediCov_c15 ${CONTROLS} if wave == 15, robust
est store medication_fifteen
estadd local Controls 		"$\checkmark$"	// add checkmark "Controls"

reg everSmoke 			mediCov_c15 ${CONTROLS} if wave == 15, robust
est store everSmoke_fifteen
estadd local Controls 		"$\checkmark$"	// add checkmark "Controls"

reg everDrink 			mediCov_c15 ${CONTROLS} if wave == 15, robust
est store everDrink_fifteen
estadd local Controls 		"$\checkmark$"	// add checkmark "Controls"

reg activityVigorous  	mediCov_c15 ${CONTROLS} if wave == 15, robust
est store activityVigorous_fifteen
estadd local Controls 		"$\checkmark$"	// add checkmark "Controls"

/* reg numRegDoc  	mediCov_c9 ${CONTROLS} if wave == 9, robust
est store numRegDoc_nine
estadd local Controls 		"$\checkmark$"	// add checkmark "Controls" */

* LaTex
label var mediCov_c15 	"Current Medicaid Coverage"
label var age			"Age"
label var moHealth		"Mother health"

estout healthFactor_a15_fifteen chHealth_15_fifteen ///
medication_fifteen everSmoke_fifteen everDrink_fifteen activityVigorous_fifteen ///
using "${TABLEDIR}/regression.tex", replace label cells(b(fmt(%9.3fc) star) se(par fmt(%9.3fc))) ///
collabels(none) ///
mlabels("Health index" "Child health" "Medication" "Ever smoke" "Ever drink" "Activity") ///
style(tex) starlevels(* .1 ** .05 *** .01) numbers ///
stats(Controls N r2, fmt(%9.0f %9.0f %9.3f) label(Controls Obs. "\$R^{2}$")) ///
varlabels(_cons Constant, blist(mediCov_c15 "\hline ") elist(_cons \hline)) // keep order
* numbers mlabels("" "" "" "" "") mgroups("`pheno'", pattern(1 0 0 0 0) prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span}))



/* 	Interpretation code
	regression here
	* As percentage of a standard deviation
	local beta_allMediHI_`wave' = _b[allMediHI]
	sum chHealth_`wave'
	local chHealth_`wave'_sd = r(sd)
	*di " Increases on average by " (`beta_allMediHI_15' / `chHealth_15_sd') " of a standard deviation"
	listcoef, help */

/* ----------------------------------  END ---------------------------------- */





* capture log close
