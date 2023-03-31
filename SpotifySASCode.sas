libname anaday "/home/u59780575/Analytics Day Spring 2023";
/**************BEGIN IMPORTING DATASET AND CHECKING ABNORMALITIES*******************************/
%web_drop_table(WORK.songs);
FILENAME REFFILE '/home/u59780575/Analytics Day Spring 2023/tracks.csv';
PROC IMPORT DATAFILE=REFFILE
	DBMS=CSV
	OUT=WORK.songs;
	GETNAMES=YES;
RUN;
PROC CONTENTS DATA=WORK.songs; RUN;
%web_open_table(WORK.songs);

data anaday.songs;
set work.songs;
run;
/*****************************************MLR******************************************************/
data anaday.songs1;
set anaday.songs;
duration_s=duration_ms/1000;
drop release_date duration_ms;
if popularity=0 then delete;
run;

proc means data=anaday.songs1 mean median nmiss;
var danceability energy loudness speechiness acousticness instrumentalness 
	liveness valence tempo duration_s;
run;

proc sgplot data=anaday.songs1;
histogram popularity;
run;

%let inputs1 = danceability energy loudness speechiness acousticness instrumentalness 
	liveness valence tempo duration_s explicit mode;
%let finalinputs = danceability energy instrumentalness 
	liveness tempo duration_s explicit mode;
	
proc corr data=anaday.songs1;
var &inputs popularity;
run;

proc reg data=anaday.songs1;
model popularity = &inputs1 / vif;
run;

title1 "Table 1: Results of Variable Clustering to Remove Multicollinearity";
proc varclus data = anaday.songs1 outtree = tree maxclusters=10;
var &inputs1;
run;
title1;	

title1 "Table 2: Final Model from Stepwise Multiple Linear Regression";
proc reg data=anaday.songs1;
model popularity = &finalinputs / selection = stepwise vif slstay=0.05 slentry=0.10;
run;

/****************************************1-WAY ANOVA*******************************************************/
data anaday.songs2;
set anaday.songs1;
if year <1920 then delete;
else if year < 1940 then 'Era of Release'n = 1;
else if year < 1960 then 'Era of Release'n = 2;
else if year < 1980 then 'Era of Release'n = 3;
else if year < 2000 then 'Era of Release'n = 4;
else 'Year Era'n = 5;

proc format;
	value category 1 = "Before 1940"
				   2 = "Between 1940 and 1960"
				   3 = "Between 1960 and 1980"
				   4 = "Between 1980 and 2000"
				   5 = "After 2000";

data anaday.songs2;
set anaday.songs2;
format 'Era of Release'n $category.;
run;

proc univariate data=anaday.songs2 plots;
	class 'Era of Release'n; /*CATEGORICAL*/
	var popularity; /*QUANTITATIVE*/
run;
title;

proc sort data=anaday.songs2 out = anaday.songs2;
	key 'Era of Release'n
	/ ascending;
	run;

title1 "Figure 1: Stratified Box-Plot of Song Popularity Stratified by Year Era";
proc sgplot data=anaday.songs2;
hbox popularity / category='Era of Release'n displaystats = (std);
run;
title1;

proc means data = anaday.songs2 n mean median std;
class 'Era of Release'n;
var popularity;
run;
*Homogeneity = 2.04;

title1 "Table 3: One-Way ANOVA Results of Popularity Based on Release Date Era";
proc ANOVA data=anaday.songs2;
   class 'Era of Release'n;
   model popularity = 'Era of Release'n;
   means 'Era of Release'n / hovtest=levene;
run;
title1;

*Tukey Test;
title1 "Figure 2: Results of Tukey Post-Hoc Test for One-Way ANOVA";
proc ANOVA data=anaday.songs2;
   class 'Era of Release'n;
   model popularity = 'Era of Release'n;
   means 'Era of Release'n / tukey lines alpha = .01;
run;
title1;
/***************************************LR********************************************************/
proc means data=anaday.songs2 median;
var popularity;
run;

data anaday.songs3;
set anaday.songs2;
if popularity <= 29 then 'Popular'n = 0;
else 'Popular'n = 1;
run;

proc freq data=anaday.songs3;
tables'Popular'n;
run;

Proc sort data=anaday.songs3 out=anaday.songs3sort;
by 'Popular'n;
Run;

Proc surveyselect data=anaday.songs3sort samprate = .65 out=anaday.moddevfile method=srs
seed = 89557 outall;
strata 'Popular'n;
Run;

Proc freq data=anaday.moddevfile;
Tables 'Popular'n*selected;
Run;

Data anaday.train anaday.valid;
set anaday.moddevfile;
if selected then output anaday.train;
else output anaday.valid;
Run;

proc freq data=anaday.train;
	tables 'Popular'n;
Run;

title1 "Table 4: Final Model of Stepwise Logistic Regression"; 	
Proc Logistic data = anaday.train des outest = betas outmodel=scoringdata  
plots=(oddsratio(cldisplay=serifarrow) roc);
model 'Popular'n =  &inputs1/selection = stepwise
 CTABLE pprob=(0.497)
 LACKFIT RISKLIMITS;
*units DCBAL= 1000 RBAL=1000;
output out = output p = predicted;
score data=anaday.valid out=anaday.score;
Run;
title1;

*Class Score = 0.497;

data score;
set anaday.score;
if p_1 = . then delete;
run;


proc print data=anaday.score (obs=50);
var 'Popular'n p_1 p_0;
where 'Popular'n = 1;
run;

data anaday.test;
set anaday.score;
if P_1 ge .497 then preds = 1;
else preds = 0;
run;

title1 "Table 5: Results of Logistic Regression Model Accuracy";
proc freq data=anaday.test;
table 'Popular'n*preds/norow nocol;
run;