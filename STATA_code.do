ssc install psmatch2
use "C:\Users\mrmoh\Downloads\projet\covid_dataset.dta", clear

label var copd "Chronic obstructive pulmonary disease"
label var icu "Intensive care unit"
label var outcome "Patient who have COVID-19"
label var patient_type "patient who are at the hospital"

tab outcome
keep if outcome==1
tab intubated
/* tab intubated

  intubated |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |        991        4.22        4.22
          2 |      8,275       35.26       39.48
         97 |     14,201       60.50       99.98
         99 |          4        0.02      100.00
------------+-----------------------------------
      Total |     23,471      100.00


*/

//We want to keep the patient who are hospitalized only so we remove those who are at home 
tab patient_type
/*tab patient_type

     if the |
 patient is |
 at home or |
     at the |
   hospital |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |     14,201       60.50       60.50
          2 |      9,270       39.50      100.00
------------+-----------------------------------
      Total |     23,471      100.00

it appears that the number of patient at home is the same as the number of patient for whom we cannot apply an intubation. 
Thus we keep those to whom we can apply it only */
	  
keep if patient_type==2

tab intubated
tab death_date

// We want to have a new variable to indicate if the patient is dead or not
gen died=1 if death_date=="9999-99-99"
replace died= 0 if died==1
replace died= 1 if died!=0
label var died "0 = not dead, 1 = dead"
tab died 
/*tab died

    0 = not |
  dead, 1 = |
       dead |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |      7,329       79.06       79.06
          1 |      1,941       20.94      100.00
------------+-----------------------------------
      Total |      9,270      100.00
*/

// Variables à traiter
local variables_to_process "sex intubated pneumonia pregnant diabetes copd asthma immunosuppression hypertension other_diseases cardiovascular obesity chronic_kidney_failure smoker icu"

// Boucle foreach pour les opérations de recodage
foreach var in `variables_to_process' {
    replace `var' = 0 if `var' != 1
}

save "C:\Users\mrmoh\Downloads\projet\covid_dataset.dta", replace


//On veut distinguer les patients selon leur tranche d'age
gen age_range="0-14" if age<15
replace age_range="15-44" if age>14 & age<45
replace age_range="45-75" if age>44 & age<76
replace age_range="75+" if age>75

summarize
drop death_date 
drop another_case

** Comparaison de l'âge moyen des patients décédés et des patients guéris**

* Calcul de l'âge moyen des patients décédés
summarize age if died == 1

* Calcul de l'âge moyen des patients guéris
summarize age if died == 0

* Frequence pour chaque catégorie d'age des patients décédés
tab age_range if died == 1

* Frequence pour chaque catégorie d'age des patients guéris
tab age_range if died == 0


** Répartition de la mortalité et de l'intubation en fonction du sexe**

* Fréquence de la mortalité des patients feminins
tab died if sex == 1

* Fréquence de la mortalité des patients masculin
tab died if sex == 0


* Fréquence d'intubation des patients feminins
tab intubated if sex == 1

* Fréquence d'intubation des patients masculin
tab intubated if sex == 0


** Répartition de la mortalité et de l'intubation en fonction des comorbiditées**

* Frequence de l'intubation en lorsque le patient est fumeur
tab intubated died  if smoker == 1

* Frequence de l'intubation en lorsque le patient est non-fumeur
tab intubated if smoker == 0

* Frequence de l'intubation en lorsque le patient est diabetique
tab intubated if diabetes == 1

* Frequence de l'intubation en lorsque le patient est non-diabetique
tab intubated if diabetes == 0

* Frequence de mortalité en lorsque le patient est fumeur
tab died if smoker == 1

* Frequence de mortalité en lorsque le patient est non-fumeur
tab died if smoker == 0

* Frequence de mortalité en lorsque le patient est diabetique
tab died if diabetes == 1

* Frequence de mortalité en lorsque le patient est non-diabetes
tab died if diabetes == 0

* Frequence de l'intubation en lorsque le patient est fumeur
tab intubated if asthma == 1

* Frequence de l'intubation en lorsque le patient est non-fumeur
tab intubated if asthma == 0

* Frequence de mortalité en lorsque le patient est asthmatique
tab died if asthma == 1

* Frequence de mortalité en lorsque le patient est non-fumeur
tab died if asthma == 0

** Repartition de la mortalité en fonction de l'intubation(treatment)**

* Frequence de la mortalité des patients intubés(traité)
tab died if intubated == 1

* Frequence de la mortalité des patients non-intubés(non-traité)
tab died if intubated == 0

tab died


global treatment intubated
global ylist died
global xlist sex pneumonia age pregnant diabetes copd asthma immunosuppression hypertension other_disease cardiovascular obesity chronic_kidney_failure smoker icu  


describe $treatment $ylist $xlist
summarize $treatment $ylist $xlist
bysort $treatment: summarize $ylist $xlist
/* */

*Probit Model
probit $ylist $treatment $xlist

*Logit Model
logit $ylist $treatment $xlist

quietly probit $ylist $treatment $xlist
margins, dydx(*) atmeans
margins, dydx(*)

* same thing but with the logit model now

quietly logit $ylist $treatment $xlist 
margins, dydx(*) atmeans
margins, dydx(*)

logistic $ylist $treatment $xlist

* Now we predict the probabilities 
quietly logit $ylist $treatment $xlist
predict plogit, pr

quietly probit $ylist $treatment $xlist 
predict pprobit, pr

summarize $ylist plogit pprobit

* We want to create the confusion matrix to have the good percent for each predicted values
quietly logit $ylist $treatment $xlist
estat classification

quietly probit $ylist $treatment $xlist
estat classification

* It's time to do the matching
* Propensity score matching
psmatch2 $treatment $xlist, outcome($ylist) ate 

* Propensity score matching with logit instead of probit model
psmatch2 $treatment $xlist, outcome($ylist) logit

* Nearest neighbor matching - neighbor(number of neighbors)
psmatch2 $treatment $xlist, outcome($ylist) common neighbor(1)

* Radius matching - caliper(distance)
psmatch2 $treatment $xlist, outcome($ylist) common radius caliper(0.1)

* Kernel matching
psmatch2 $treatment $xlist, outcome($ylist) common kernel

* Bootstrapping 
set seed 0
bootstrap r(att): psmatch2 $treatment $xlist, outcome($ylist)

* It may be possible that the number of comorbidities of the patient impact his probability to die
egen comorbidities=rowtotal(pneumonia diabetes copd asthma immunosuppression hypertension other_diseases cardiovascular obesity chronic_kidney_failure smoker )

summarize comorbidities
tab died if comorbidities>=4
tab comorbidities if intubated==1
tab comorbidities if intubated==0
mean comorbidities if intubated==0
mean comorbidities if intubated==1


* Since our model is not significant, we will try to affine it to see if it could be better without some variable.
* We are going to applicate the same method but with respect to the sex and to the age range. 

********************************************************************************
********************************* Without sex **********************************
********************************************************************************


use "/Users/souhil/Downloads/datacovid.dta", clear

global treatment intubated
global ylist died
global xlist pneumonia age pregnant diabetes copd asthma immunosuppression hypertension other_disease cardiovascular obesity chronic_kidney_failure smoker icu  

describe $treatment $ylist $xlist
summarize $treatment $ylist $xlist
bysort $treatment: summarize $ylist $xlist

* As we saw previously, the probit logit models are not necessary

* Propensity score matching
psmatch2 $treatment $xlist, outcome($ylist) ate 

* Propensity score matching with logit instead of probit model
psmatch2 $treatment $xlist, outcome($ylist) logit

* From now we only use the Kernel matching
psmatch2 $treatment $xlist, outcome($ylist) common kernel

* Bootstrapping 
set seed 0
bootstrap r(att): psmatch2 $treatment $xlist, outcome($ylist)


********************************************************************************
******************************** With men only *********************************
********************************************************************************

use"C:\Users\mrmoh\Downloads\projet\covid_dataset.dta", clear
keep if sex==0
global treatment intubated
global ylist died
global xlist sex pneumonia age pregnant diabetes copd asthma immunosuppression hypertension other_disease cardiovascular obesity chronic_kidney_failure smoker icu  

describe $treatment $ylist $xlist
summarize $treatment $ylist $xlist
bysort $treatment: summarize $ylist $xlist


* Propensity score matching
psmatch2 $treatment $xlist, outcome($ylist) ate 

* Propensity score matching with logit instead of probit model
psmatch2 $treatment $xlist, outcome($ylist) logit

* Kernel matching
psmatch2 $treatment $xlist, outcome($ylist) common kernel

* Bootstrapping 
set seed 0
bootstrap r(att): psmatch2 $treatment $xlist, outcome($ylist)



********************************************************************************
****************************** With women only *********************************
********************************************************************************

use "/Users/souhil/Downloads/datacovid.dta", clear
keep if sex==1
global treatment intubated
global ylist died
global xlist sex pneumonia age pregnant diabetes copd asthma immunosuppression hypertension other_disease cardiovascular obesity chronic_kidney_failure smoker icu  

describe $treatment $ylist $xlist
summarize $treatment $ylist $xlist
bysort $treatment: summarize $ylist $xlist


* Propensity score matching
psmatch2 $treatment $xlist, outcome($ylist) ate 

* Propensity score matching with logit instead of probit model
psmatch2 $treatment $xlist, outcome($ylist) logit

* Kernel matching
psmatch2 $treatment $xlist, outcome($ylist) common kernel

* Bootstrapping 
set seed 0
bootstrap r(att): psmatch2 $treatment $xlist, outcome($ylist)



********************************************************************************
******************************* Without age ************************************
********************************************************************************

use "C:\Users\mrmoh\Downloads\projet\covid_dataset.dta", clear

global treatment intubated
global ylist died
global xlist sex pneumonia pregnant diabetes copd asthma immunosuppression hypertension other_disease cardiovascular obesity chronic_kidney_failure smoker icu  

describe $treatment $ylist $xlist
summarize $treatment $ylist $xlist
bysort $treatment: summarize $ylist $xlist


* Propensity score matching
psmatch2 $treatment $xlist, outcome($ylist) ate 

* Propensity score matching with logit instead of probit model
psmatch2 $treatment $xlist, outcome($ylist) logit

* Kernel matching
psmatch2 $treatment $xlist, outcome($ylist) common kernel

* Bootstrapping 
set seed 0
bootstrap r(att): psmatch2 $treatment $xlist, outcome($ylist)


********************************************************************************
****************************** Only if age >= 45 *******************************
********************************************************************************

use "C:\Users\mrmoh\Downloads\projet\covid_dataset.dta", clear
keep if age_range=="45-75" |age_range=="75+"
global treatment intubated
global ylist died
global xlist sex age pneumonia pregnant diabetes copd asthma immunosuppression hypertension other_disease cardiovascular obesity chronic_kidney_failure smoker icu  

describe $treatment $ylist $xlist
summarize $treatment $ylist $xlist
bysort $treatment: summarize $ylist $xlist


* Propensity score matching
psmatch2 $treatment $xlist, outcome($ylist) ate 

* Propensity score matching with logit instead of probit model
psmatch2 $treatment $xlist, outcome($ylist) logit

* Kernel matching
psmatch2 $treatment $xlist, outcome($ylist) common kernel

* Bootstrapping 
set seed 0
bootstrap r(att): psmatch2 $treatment $xlist, outcome($ylist)


********************************************************************************
****************************** Only if age < 45 *******************************
********************************************************************************

use "C:\Users\mrmoh\Downloads\projet\covid_dataset.dta", clear
keep if age_range=="0-14" |age_range=="15-44"
global treatment intubated
global ylist died
global xlist sex age pneumonia pregnant diabetes copd asthma immunosuppression hypertension other_disease cardiovascular obesity chronic_kidney_failure smoker icu  

describe $treatment $ylist $xlist
summarize $treatment $ylist $xlist
bysort $treatment: summarize $ylist $xlist


* Propensity score matching
psmatch2 $treatment $xlist, outcome($ylist) ate 

* Propensity score matching with logit instead of probit model
psmatch2 $treatment $xlist, outcome($ylist) logit

* Kernel matching
psmatch2 $treatment $xlist, outcome($ylist) common kernel

* Bootstrapping 
set seed 0
bootstrap r(att): psmatch2 $treatment $xlist, outcome($ylist)


********************************************************************************
*************************** With more than 3 comorbidities *********************
********************************************************************************

use "C:\Users\mrmoh\Downloads\projet\covid_dataset.dta", clear

egen comorbidities=rowtotal(pneumonia diabetes copd asthma immunosuppression hypertension other_diseases cardiovascular obesity chronic_kidney_failure smoker )
keep if comorbidities >3

global treatment intubated
global ylist died
global xlist sex pneumonia age pregnant diabetes copd asthma immunosuppression hypertension other_disease cardiovascular obesity chronic_kidney_failure smoker icu comorbidities

describe $treatment $ylist $xlist
summarize $treatment $ylist $xlist
bysort $treatment: summarize $ylist $xlist

* Propensity score matching
psmatch2 $treatment $xlist, outcome($ylist) ate 

* Propensity score matching with logit instead of probit model
psmatch2 $treatment $xlist, outcome($ylist) logit

* Kernel matching
psmatch2 $treatment $xlist, outcome($ylist) common kernel

* Bootstrapping 
set seed 0
bootstrap r(att): psmatch2 $treatment $xlist, outcome($ylist)


********************************************************************************
*************************** With less than 3 comorbidities *********************
********************************************************************************

use "C:\Users\mrmoh\Downloads\projet\covid_dataset.dta", clear

egen comorbidities=rowtotal(pneumonia diabetes copd asthma immunosuppression hypertension other_diseases cardiovascular obesity chronic_kidney_failure smoker )
keep if comorbidities <3

global treatment intubated
global ylist died
global xlist sex pneumonia age pregnant diabetes copd asthma immunosuppression hypertension other_disease cardiovascular obesity chronic_kidney_failure smoker icu comorbidities

describe $treatment $ylist $xlist
summarize $treatment $ylist $xlist
bysort $treatment: summarize $ylist $xlist

* Propensity score matching
psmatch2 $treatment $xlist, outcome($ylist) ate 

* Propensity score matching with logit instead of probit model
psmatch2 $treatment $xlist, outcome($ylist) logit

* Kernel matching
psmatch2 $treatment $xlist, outcome($ylist) common kernel

* Bootstrapping 
set seed 0
bootstrap r(att): psmatch2 $treatment $xlist, outcome($ylist)





