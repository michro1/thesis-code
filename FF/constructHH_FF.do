* -----------------------------------
* Project:      MA Thesis
* Content:      HH structure FF
* Data:         Fragile families
* Author:       Michelle Rosenberger
* Date:         November 7, 2018
* -----------------------------------

/* This code combines all the waves and constructs the necessary variables
for the household structure in the Fragile Families data.

* ----- INPUT DATASETS (TEMPDATADIR):
parents_Y0.dta; parents_Y1.dta; parents_Y3.dta; parents_Y5.dta;
parents_Y9.dta; parents_Y15.dta; states.dta

* ----- OUTPUT DATASETS (TEMPDATADIR):
household_FF.dta
*/

* ---------------------------------------------------------------------------- *
* --------------------------------- PREAMBLE --------------------------------- *
* ---------------------------------------------------------------------------- *
capture log close
clear all
est clear
set more off
set emptycells drop
set matsize 10000
set maxvar 10000

* ----------------------------- SET WORKING DIRECTORIES & GLOBAL VARS
if "`c(username)'" == "michellerosenberger"  {
    global USERPATH     "~/Development/MA"
}

global RAWDATADIR	    "${USERPATH}/data/raw/FragileFamilies"
global CLEANDATADIR  	"${USERPATH}/data/clean"
global TEMPDATADIR  	"${USERPATH}/data/temp"
global CODEDIR          "${USERPATH}/code"
global TABLEDIR         "${USERPATH}/output/tables"

cd ${CODEDIR}

* ---------------------------------------------------------------------------- *
* ------------------------------ VARIABLES MERGE ----------------------------- *
* ---------------------------------------------------------------------------- *

* ----------------------------- MERGE
use "${TEMPDATADIR}/parents_Y0.dta", clear

foreach wave in 1 3 5 9 15 {
    append using "${TEMPDATADIR}/parents_Y`wave'.dta"
}

* ----------------------------- RENAME
rename moYear       year
rename chFAM_size   famSize
rename chHH_size    hhSize
rename chAvg_inc    avgInc
rename chHH_income  hhInc
rename incRatio     incRatio_FF
rename chAge        chAge_temp

* ----------------------------- AGE
bysort idnum (year) : gen diff = year[_n+1] - year[_n]
bysort idnum (year) : replace chAge_temp =  chAge_temp[_n+1] - diff[_n]*12 if wave == 0

gen chAge = int(chAge_temp / 12)
replace chAge = 0 if chAge < 0

* ----------------------------- MERGE STATE (RESTRICTED USE DATA)
merge 1:1 idnum wave using "${TEMPDATADIR}/states.dta", nogen
rename state statefip

* ----------------------------- GENDER, RACE, MOTHER AGE, MOTHER RACE
foreach var in chGender moAge moCohort moWhite moBlack moHispanic moOther ///
moEduc chBlack chHispanic chOther chMulti chWhite chRace {
    rename  `var' `var'_temp
    egen    `var' = max(`var'_temp), by(idnum) 
}

recode chGender (2 = 1) (1 = 0)
rename chGender chFemale

* ----------------------------- FAM INCOME IN THOUSANDS
replace avgInc = avgInc / 1000

* ----------------------------- FORMAT & SAVE
* ----- DROP
drop chAge_temp diff *_temp moHH_size_c ratio_size

* ----- LABELS
label data              "Household structure FF"

label var idnum         "Family ID"
label var year          "Year interview"
label var wave          "Wave"
label var moReport      "Mother report used"
label var famSize       "Family size"
label var avgInc        "Family income (in 1'000 USD)"
label var hhSize        "Household size"
label var hhInc         "Household income"
label var incRatio_FF   "Poverty ratio from FF"
label var statefip      "State of residence (FIP)"
label var chAge         "Child's age"
label var chFemale      "Child female"
label var chRace        "Child's race"
label var chWhite       "Child's race white"
label var chBlack       "Child's race black"
label var chHispanic    "Child's race hispanic"
label var chOther       "Child's race other"
label var chMulti       "Child's race mutli-racial"
label var moAge         "Mother's age at birth"
label var moEduc        "Mother's education"
label var moCohort      "Mother's birth year"
label var moWhite       "Mother's race white"
label var moBlack       "Mother's race black"
label var moHispanic    "Mother's race hispanic"
label var moOther       "Mother's race other"

* ----- VALUE LABELS
label define chFemale       0 "0 Male"                  1 "1 Female"
label define moReport       0 "0 No"                    1 "1 Yes"
label define raWhite        0 "0 Non-white"             1 "1 White"
label define raBlack        0 "0 Non-black"             1 "1 Black"
label define raHispaninc    0 "0 Non-hispanic"          1 "1 Hispanic"
label define raOther        0 "0 Non-other"             1 "1 Other"
label define raMutli        0 "0 non-multi"             1 "1 Multi-racial"
label define moEduc         1 "1 Less than HS"          2 "2 HS or equivalent" ///
                            3 "3 Some college, tech"    4 "College or Grad"
label define chRace         1 "1 White" 2 "2 Black" 3 "3 Hispanic" 4 "4 Other" 5 "Multi-racial"

label values chFemale chFemale
label values moReport moReport
label values chWhite moWhite raWhite
label values chBlack moBlack raBlack
label values chHispanic moHispanic raHispaninc
label values chOther moOther raOther
label values chMulti raMutli
label values moEduc moEduc
label values chRace chRace

* ----- LABELS
* NOTE: ONE observation per WAVE and ID
order idnum wave year chAge famSize statefip chFemale
sort idnum wave

describe
save "${TEMPDATADIR}/household_FF.dta", replace

