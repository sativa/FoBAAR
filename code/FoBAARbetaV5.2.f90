! The FoBAAR model
! developed by Trevor F. Keenan, Apr 2013

! V5.2

! -------------------------------------------------------------
! previous version betaV5.1
! developed for the CarboExtreme project
! changes from previous version: new soil water content module
! -------------------------------------------------------------


! !!!!!! NOTE  - FILE PATHS MUST BE CHANGED FOR ANY APPLICATION
! !!!!!! see the variables 'home', 'forest', and any instances of 'unit='

module obsdrivers

! for use in printing execution time....
real, dimension(2) :: tarray
real :: result
 
! set the home directory 
character(len=18), parameter:: home = 'Users/trevorkeenan'	

! set as a run identifier for running different configurations
integer,parameter :: rep =1


! the following parameters control the optimization
integer, parameter :: r =1!00						! number of wandering iterations (from 1 to 10000. not absolutely necessary)
integer, parameter :: q = 2!15000					! number of optimization iterations (from 2 to 100000. usually about 10000 is sufficient)       
integer, parameter :: initial =1				        	! starting value 0: new optimization 1: start from previous best
integer, parameter :: explore =1!0 !10000	    		! maximum number of parameter sets in explore stage (program exits if reached)


! -------------------------------------------------------------

! Here we set the length of the simulation
! Part of the time series is used for optimization
! whilst the other part can be used only for testing the model

! -------------------------------------------------------------
!!			Deciduous CarboExtreme SITES

!! FR-Hes.  All years. Last two years for testing
character(len=*), parameter:: forest = 'FRHes'
integer, parameter :: NOAA=1
integer, parameter :: stday =1+365*0
integer, parameter :: stdaycal =stday+(365*0)
integer, parameter :: ndaycal= stday+(365*1) +1
integer, parameter :: nday=ndaycal+(365*1)+1
integer, parameter :: nyears = nday/365
integer,parameter :: subDaily = 48.								! 1 for daily, 24 for hourly, 48 for half hourly (half-hourly untested!)
 

! -------------------------------------------------------------
!!			Evergreen CarboExtreme SITES

! FR-LBr. All years. Last two years for testing 
!character(len=*), parameter:: forest = 'FRLBr'
!integer, parameter :: NOAA=1					
!integer, parameter :: stday =1+365*0	         		
!integer, parameter :: stdaycal =stday+(365*0)			
!integer, parameter :: ndaycal= stday+(365*11) +2      	
!!integer, parameter :: ndaycal= stday+(365*2) +2      	
!integer, parameter :: nday=ndaycal+(365*2)+1	
!integer, parameter :: nyears = nday/365
!integer,parameter :: subDaily = 48.		

! -------------------------------------------------------------
! ---------- 	Set the parameters for the optimization (do not change)

real, parameter :: acceptanceRate=0.15  
integer, parameter :: exploreLength =(explore/acceptanceRate)/1.3 	! maximum number of iterations in search stage 
integer, parameter :: numOuterRuns=1							! both obsolete
integer, parameter :: numInnerRuns=1
integer, parameter :: nparm = 50								! parameters dynamic based on the number of soil layers
 
! -------------------------------------------------------------
! ---------- 	Set the values of files to be read in and location of data within files. 
! ----------  Each number identifies the column location of the data in the data file
! ----------  Do not change unless the input files are changed

integer, parameter :: numConstraints = 28

integer,parameter :: numColumnsFlux=14
integer,parameter :: numColumnsMet=10
integer,parameter :: numColumnsBio=17

integer,parameter :: indexMETtemp=4
integer,parameter :: indexMETpar=5
integer,parameter :: indexMETvpd=6
integer,parameter :: indexMETrh=7
integer,parameter :: indexMETsoilT=8
integer,parameter :: indexMETco2=9
integer,parameter :: indexMETprecip=10

integer,parameter :: indexFLUXnee=4
integer,parameter :: indexFLUXneeE=5

integer,parameter :: indexFLUXneegf=6
integer,parameter :: indexFLUXle=7
integer,parameter :: indexFLUXleE=8
integer,parameter :: indexFLUXlegf=9
integer,parameter :: indexFLUXgpp=11
integer,parameter :: indexFLUXgppgf=12
integer,parameter :: indexFLUXre=13
integer,parameter :: indexFLUXregf=14

integer,parameter :: indexMETProjectDay=2
integer,parameter :: indexMETDayHour=3

integer,parameter :: indexBioCw=11
integer,parameter :: indexBioCwE=12
integer,parameter :: indexBioCwInc=13
integer,parameter :: indexBioCwIncE=14
integer,parameter :: indexBioSoilTotC=15
integer,parameter :: indexBioSoilTotCe=16
integer,parameter :: indexBioLAI=4
integer,parameter :: indexBioLAIe=5
integer,parameter :: indexBioLitterF=6
integer,parameter :: indexBioLitterFe=7
integer,parameter :: indexBioPhenology=8
integer,parameter :: indexBioPhenologyE=9

integer,parameter :: numSubDailyVariablesOut=31
integer,parameter :: numDailyVariablesOut=81

! -------------------------------------------------------------
! 	Extras

integer:: iter,lastrun,innerRun,outerRun  
real :: airT,ma_AirT,soilt,rad,rh,par,nit,day,ca,lat,yearday,projectday
real :: neemeas(3),neemeasDailyDay(3),neemeasDailyNight(3),neemodDailyDay(1),neemodDailyNight(1)
real :: litterfallmeas(2),bbdate,laimeas(2)
real :: cwmeas,cwmeasE,cwmeasInc,cwmeasIncE,cwInc,cwPreviousYear
real :: soilTotCmeas,soilTotCmeasE
real :: rsoilmeas(3,2)
real :: floatingIter,floatingAcc, floatingAns, floatingStepflag
real :: swc,swhc        ! soil water content

! set how many soil pools the model should used (depreciated? do not change)
integer,parameter :: numSoilPools = 3 			! 1,2 (fast, slow), 3 (fast, intermediate, slow)


! -------------------------------------------------------------
end module obsdrivers 

! ---------- ---------- ---------- ---------- ---------- ----------
! ---------- ---------- ---------- ---------- ---------- ----------
! ---------- ---------- ---------- ---------- ---------- ----------
! Begin the integrated FoBAAR MDF code
! ---------- ---------- ---------- ---------- ---------- ----------

Program FoBAAR
use obsdrivers
 
implicit none

! Initialize the many variables that the model will use.
! Any new variable introduced to the code must be initialized here.
real :: G,GDaily,GDaily2,GDailyPrevious,GsubDaily,PhotoSynth
real :: Gc,GcDaily,GcDAily2,GcSubDaily,ETsubDaily,ETDaily(2),ETmeasDaily(3)
real :: NeeDaily,NeeDailyMeas,posteriorChiSqTest
real :: PPFDsun,PPFDshd,radDaily,precipDaily
real :: VPD
real :: LAI,AssignLai,LAISun
real :: leafout,leafin,leafinmeas(2),leafoutmeas(2)
real :: Trate,TrateDaily,TrateS,TrateDailyS,TrateRoot,Tadj,Tadj2,gdd(2),rnorm
real :: Rroot, RrootDaily
real :: NEE,iGPP,iNEE(4),iNEEmeas(4),iRa,iDresp,iRroot,iRh,iRhLit,iRh1,iRh2,iRh3,iRsoil(3),RsoilModDaily,iRsoilmeas
real :: annualNEE(nyears),annualGPP(nyears),annualRa(nyears),annualRh(nyears)
real :: cwMeasFirstLast(2),cwModFirstLast(2),de,RealityErr,dayflag(nday,subDaily)
real :: P(nparm),incP(nparm),stepSize(nparm),absoluteBoundsP(nparm,2),boundsP(nparm,2)
real :: parameters(numInnerRuns,(q*(numOuterRuns)+(exploreLength)),nparm)
real :: error(numInnerRuns,(q*(numOuterRuns)+exploreLength),3)
real :: lastvalueCwMeas,lastvalueCwMod
real :: constraints(numConstraints+1)

real :: accparm(explore,numInnerRuns,nparm+1),oldP(nparm),bestP(nparm),deltap(nparm)
real :: LMA,max_fol,multtl,multtf,ralabfrom,ralabto, ralabtoDaily,ralabfromDaily
real :: Ra,Af,Aw,Ar,Lf(2),Lw,iLw,Lr,RhLit,Rh1,RaDaily,RhLitDaily,Rh1Daily,Rh2,Rh2Daily,Rh3,Rh3Daily,Atolab,Afromlab,npp
real :: Cf,Cw,Cr,Clab,Clit,Csom,CsomPools(numSoilPools)
real :: annealstart,annealtemp,cooling(1),besterr,allbest
real :: err(numConstraints,2),toterr,TotalErrorV4,TotalErrorV4bayes,countD(numConstraints),qerr(numConstraints)
real :: ran,expo,fAparDaily
real :: Xfang,Vcmax,EaVcmax,EdVcmax,EaJmax,EdJmax,SJmax,Rd,Rdt,gs,Dresp,DrespDaily,VQ10    	
real :: Dlit,D1,D2,iD1,iD2,iDlit	

real :: innerRunParameters(2,numInnerRuns,nparm)
real :: innerRunIncP(2,numInnerRuns,nparm)
real :: innerRunBoundsP(2,numInnerRuns,nparm,2)
real :: bestInnerRunTotError

real :: bSoilMeas(3)
real :: prange(nparm,2)
real :: innerRunOutSubDaily(numInnerRuns,nday,subDaily,numSubDailyVariablesOut)
real :: innerRunOutDaily(numInnerRuns,nday,numDailyVariablesOut),pred(numInnerRuns,nday,numDailyVariablesOut)
real :: posteriorFluxComponents(explore,nyears*4)         ! the posterior flux components are NEE GPP Ra Rh
real :: cl(nday,numDailyVariablesOut,2)
real :: clLow(numInnerRuns,nday,numDailyVariablesOut), clHigh(numInnerRuns,nday,numDailyVariablesOut)

real :: metData(nday,subDaily,numColumnsMet)
real :: fluxData(nday,subDaily,numColumnsFlux)
real :: bioData(nday,numColumnsBio)
real :: soilTemp(nday,subDaily)
real :: maxt(nday),mint(nday)
real :: period                                                                ! the number of time intervals during a day

real :: drainage,runoff,soilWaterContent                                                  ! soil water variables

! temporary holding variables
real :: xx,tmp,tmp2,tmp3,tmp4
real :: waterStress

double PRECISION :: toterrAll

integer :: acc(numInnerRuns),ans,stepflag,laststep,acceptflag,jfunct,decidflag,DecidOrEvg
integer :: i,j,k,firstexplore,startIteration,endIteration
integer :: bestInnerRun
integer :: countParamSets,countTotalIterations,countExplore,flag
integer :: nparams
integer :: year
integer :: longTerm                        ! this will be set to 0 for normal run, 1 for longTerm run (>50 yrs)

integer :: seed_size
integer,allocatable :: seed(:)

character(len=150):: filename,filename1
character(len=15):: filenum(5)
character(len=15):: repChar

call random_seed() 		 		! initialize with system generated seed
call random_seed(size=seed_size) 	! find out size of seed
allocate(seed(seed_size))
call random_seed(get=seed) 	 	! get system generated seed

! depending on the number of soil pools, set the number of parameters.
if(numSoilPools.eq.1)then
	nparams=40
else if (numSoilPools.eq.2) then
	nparams=42
else
	nparams=46
endif

! define the time-integrating period for rates, etc.
period=24./subDaily

! check whether this is a longTerm or standard run
if (nyears.gt.50)then
        longTerm=1
endif

! set whether the current site is deciduous or evergreen
DecidOrEvg=1 ! deciduous

! for CarboExtreme evergreen sites
if((forest.eq.'FRLBr').or.(forest.eq.'FRLBr200'))then
		DecidOrEvg=0
endif


DECID_EVERGREEN: do decidflag =DecidOrEvg,DecidOrEvg ! flag = 0 for evergreen, 1 for deciduous. Good exampe of bad coding!	

COST: do jfunct = 2,2	! this loop is depreciated and no longer serves a function
write(*,*) 


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!! Read the driver data from file
call readObservedData(bioData,maxt,mint,fluxData,metData,Dayflag,soilTemp,longTerm)
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

! print information about the current simulation to screen
write(repChar,*)rep

print *, "Running ...."
	print *, 'Site Name:'
		print *, forest
	print *, 'Decid (1)/Evergreen (0)'
		print *, decidflag
	print *, 'Rep:'
              print *, rep


! Load the data that tells the model which constraints to use in current simulation
open(unit=1,file=&
	&'/'//home//'/Dropbox/11.CarboExtreme/FoBAAR/FoBAARbetaV5_'//forest//'/Constraints/&
	&constraints_'//trim(adjustl(repChar))//'.csv',status='old')
	read(1,*)	! skip the header info
	read(1,*)(constraints(i),i=1,numConstraints+1)
close(1)


countTotalIterations=1
OUTER: DO outerRun = initial,numOuterRuns


! INPUT PARAMETERS
! only on first pass...
if(initial.eq.1)then
	if (decidflag.eq.1) then
		open(unit=33,file='/'//home//'/Results/CarboExtreme/FoBAAR/FoBAARbetaV5/'//forest//'/Data/&
		&initialRun_D_'//trim(adjustl(repChar))//'.csv',status='old')	
	else
		open(unit=33,file='/'//home//'/Results/CarboExtreme/FoBAAR/FoBAARbetaV5/'//forest//'/Data/&
		&initialRun_E_'//trim(adjustl(repChar))//'.csv',status='old')		
	endif
	
	read(33,*)(P(i),i=1,nparams)
	close(33)
endif
 
! initialize the parameter bounds
if(outerRun.eq.initial)then		! read in only on first pass
	
	open(unit=27,file=&
		&'/'//home//'/Dropbox/11.CarboExtreme/FoBAAR/FoBAARbetaV5_'//forest//'/&
		&initial_P_rangesV5_2rep'//trim(adjustl(repChar))//'.csv',status='old')
	do i=1,nparams
        read(27,*) absoluteBoundsP(i,1),absoluteBoundsP(i,2),boundsP(i,1),boundsP(i,2)
    end do


	!read(27,*)(absoluteBoundsP(i,1),i=1,nparams)
	!read(27,*)(absoluteBoundsP(i,2),i=1,nparams)
	!read(27,*)(boundsP(i,1),i=1,nparams)
	!read(27,*)(boundsP(i,2),i=1,nparams)
	
		read(27,*) Lat,Nit,LMA
		lat=lat*3.14/180.0		!convert to radians
	close(27)
endif

! reset incP at 5% of bounds. This is the initial step size for the markov chain walk.
incP(:)=0.075*(boundsP(:,2)-boundsP(:,1))

if (outerRun.eq.0) then
	P(:)=(boundsP(:,1)+boundsP(:,2))/2.
	incP(:)=0.4*(boundsP(:,2)-boundsP(:,1)) ! 40% of initial parameter range. This value is arbitrary, but 40% gives fast convergence.
endif


prange(:,1)=P(:)
prange(:,2)=P(:)

firstexplore = 0
besterr=9999999999.
bestInnerRunTotError=9999999999.
allbest=besterr
bestInnerRun=0

InnerRunIncP=0
InnerRunBoundsP=0
InnerRunParameters=0
!InnerRunResults=0
accparm=0
acc=1
oldp=P
bestp=P
err=0

! define the initial anneal temperature
annealstart=100
annealtemp=annealstart

! define the speed at which the temperature cools
cooling(1)=.001**(1/real(q-r))	

! initialize variables
qerr=1    
cl(:,:,1)=-10E6
cl(:,:,2)=10E6
clLow=-10E6
clHigh=10E6

countParamSets=1 
stepflag = 0
laststep=1
acceptflag = 0
startIteration=1
stepSize=0.05
tmp4=0


Do innerRun=1,numInnerRuns

	countExplore=0
	
	countParamSets=1 
	if ((outerRun.gt.0)) then
		startIteration=r
		endIteration=q
		else
		endIteration=r
	endif
	
! ---------------------------------------------------------
! ---------------------------------------------------------
! ---------- This is the start of the optimization loop
! ---------- Everything within this loop is performed with a different set of model parameters
	
			mcloop: do iter=startIteration,endIteration+exploreLength

			! this block of code generates the set of parameters for the current iteration 
			if ((iter.gt.1).and.(iter.le.q)) then
			
				if (iter.gt.r) then	! cool anneal temperature
					annealtemp=annealtemp*cooling(1)
				endif
				
				do j=1,nparams	! move from current parameter set
				
					if (stepflag.eq.0)then
						deltap(j)=rnorm(seed)*incp(j)
					endif
					
					if (stepflag.eq.1) deltap(j)=deltap(j)
		
					p(j)=oldp(j)+deltap(j)
										
					if (p(j).lt.boundsp(j,1)) then ! if the parameters fall outside the absolute limit, bounce them back
						p(j)=boundsp(j,1)+(boundsp(j,1)-p(j))/2
					endif
					if (p(j).gt.boundsp(j,2)) then
						p(j)=boundsp(j,2)+(boundsp(j,2)-p(j))/2
					endif
						
					if(boundsp(j,1).eq.boundsp(j,2))then
					        p(j)=boundsp(j,1)
					endif
				end do	
			
				if ((iter.eq.r).or.(iter.eq.endIteration)) then 
					P=bestP
					stepflag=-1
				endif
			endif
			
			! Post-optimization, the parameters can explore beyond the prior parameter ranges
			! this block of code generates the set of parameters for the post-optimization exploration of the parameter space
			if(iter.gt.q)then		! in parameter space explore stage
				do j=1,nparams	! move parameter
					
					deltap(j)=rnorm(seed)*incp(j)
					
        				p(j)=oldp(j)+deltap(j)
				
						if((iter-q).lt.5000)then
							tmp4=0.15		! initial fast expansion of range
						else
							tmp4=0.1
						endif
							
					if (p(j).lt.(prange(j,1)-(tmp4*abs(prange(j,1))))) then ! if the parameters fall more than 10% outside the range, bounce them back
						p(j)=prange(j,1)+(prange(j,1)-p(j))/2
					endif
					if (p(j).gt.prange(j,2)+(tmp4*abs(prange(j,2)))) then
						p(j)=prange(j,2)+(prange(j,2)-p(j))/2
					endif

					if(boundsp(j,1).eq.boundsp(j,2))then
						p(j)=boundsp(j,1)
					endif

					! set absolute bounds
					if (p(j).lt.(absoluteBoundsP(j,1))) then
						p(j)=absoluteBoundsP(j,1)
						endif
					if (p(j).gt.(absoluteBoundsP(j,2))) then
						p(j)=absoluteBoundsP(j,2)
						endif
						
				end do	
				
			endif
                        
                        ! the following code initializes variables to parameter values 
                        ! and zeros other variables 
			if(decidflag.eq.1)then
			        Cf = 0
			else
			        Cf=p(12)
			endif
			
			Cr = P(19)
			Cw = P(20)
			Clit = P(21)
			Clab = P(23)
			swhc= p(46) ! initialize soil water content to be at holding capacity
			swc=swhc
			droughtEdge=p(16)*swhc  ! drought effects start at this level

			CsomPools(1)=P(22) 
			CsomPools(2)=p(42) 
			CsomPools(3)=p(43) 
			
			! parameters to account for the possibility that soil resp measurements do not represent tower footprint average
			bSoilMeas(1)=P(38)
			bSoilMeas(2)=P(39)
			bSoilMeas(3)=P(40)
	
	                ! pseudo (assumed!) constants 
			Xfang=0.5	
			Vcmax= P(30)
			EaVcmax= 76459
			EdVcmax=220121	
			EaJmax= 44370
			EdJmax= 213908
			SJmax= 710 
			Rd= P(36)*0.01
			VQ10= P(37)  
				
			G = 0
			iGPP = 0
			iNEE = 0
			iNEEmeas=0
			iRa = 0
			iDresp=0
			iRroot=0
			iRh = 0
			iRhLit=0
			iRh1 = 0
			iRh2 = 0
			iRh3 = 0
			iD1=0
			iD2=0
			iDlit=0
			iRsoil = 0
			iRsoilmeas=0
			iLw=0
			atolab=0
			afromlab=0
			Lf(2)=0
			ca = 358
			err = 0
			RealityErr=0
			toterr=0
			leafout=0
			leafin=0
			cwMeasFirstLast=-10E6
			cwModFirstLast=-10E6
			lastvalueCwMeas=0
			lastvalueCwMod=0
			cwPreviousYear=0
			year=0
			
			countD=0	! occurance of observations set to zero for each loop

! -----------------------------------------------------------------
! -----------------------------------------------------------------
! ------ We have now assigned the parameters and initialized variables
! ------ So we run the model for the current parameter set				
		
		timeloop: do i=stday,nday         ! loop through each day of the simulation
		
			! check the current day of year	
			yearday=metData(i,1,indexMETProjectDay)
			
			if((yearday.ge.1.0).and.(yearday.lt.2))then			! reset some variables at the start of each year
        		        year=year+1
				leafin=0
				leafout=0
				leafinmeas=-999
				leafoutmeas=-999
				ma_AirT=0
				cwPreviousYear=cw
			endif
			
			! calculate moving average airTemperature for leaf drop estimate
			! start from mid-point of each year (only used for leaf fall date estimates) 
			if (yearday.gt.150) then
				ma_AirT=(sum(mint(i-10:i)))*0.1
			endif

                        ! grab the wood biomass measurements	
			if(bioData(i,indexBioCw).gt.0) then
				cwmeas=bioData(i,indexBioCw)
                                cwmeasE=bioData(i,indexBioCwE)
			else
				cwmeas=-999
			endif
			
                        ! grab the wood increment measurements	
			if(bioData(i,indexBioCwInc).gt.0) then
				cwmeasInc=bioData(i,indexBioCwInc)
				cwmeasIncE=bioData(i,indexBioCwIncE)
			else
				cwmeasInc=-999
			endif
				
                        ! grab the soil c measurements
			if(bioData(i,indexBioSoilTotC).gt.0) then
				soilTotCmeas =bioData(i,indexBioSoilTotC)
                                soilTotCmeasE =bioData(i,indexBioSoilTotCe)
			else
				soilTotCmeas=-999
			endif

                        ! grab the litterfall measurements
			litterfallmeas(1)=bioData(i,indexBioLitterF)
			if(litterfallmeas(1).gt.-999)then
				litterfallmeas(2)=bioData(i,indexBioLitterFe)
			else	
				litterfallmeas(2)=0
			endif
			
			! grab bud-burst and leaf fall measurements
			if((bioData(i,indexBioPhenology).eq.1))then
				leafoutmeas(1)=yearday
				leafoutmeas(2)=bioData(i,indexBioPhenologyE)
			endif
			if((bioData(i,indexBioPhenology).eq.2))then
				leafinmeas(1)=yearday
				leafinmeas(2)=bioData(i,indexBioPhenologyE)
			endif

			! at new year, start incremental values
			if((i.eq.stday).or.((yearday.ge.1.0).and.(yearday.lt.2))) then
			        ! if at end of year, record annual values
			        if(year.gt.1)then
				        annualNEE(year-1)=iNEE(1) ! this is the annual NEE
				        annualGPP(year-1)=iGPP
				        annualRa(year-1)=iRa
				        annualRh(year-1)=iRh
			        endif
			        
				iGPP = 0
				iNEE = 0
				iNEEmeas=0
				iRa = 0
				iDresp=0
				iRroot=0
				iRh = 0
				iRhLit=0
				iRh1 = 0
				iRh2 = 0
				iRh3 = 0
				iD1=0
				iD2=0
				iDlit=0
				iRsoil = 0
				iRsoilmeas=0
				iLw=0
				Lf(2)=0
			endif
	 				
				! calculate the growing degree days (gdd)
				! max_fol, multtf, multtl values. These control phenology later in the code
				if (decidflag.eq.1) then
					if(yearday.le.p(25))then
						gdd=0.
						max_fol=1.
					endif
				  
					!time switch defaults
					multtf=1.		! turnover of foliage on
					multtl=0.		! turnover of labile C off
					
				 	gdd(1)=gdd(1)+0.5*max(maxt(i)+mint(i),0.0)		!growing degree day heat sum from day p(25)
			
					If(gdd(1).ge.p(12))THEN	        !winter end (if we have got to the end of winter temperature)
						IF(max_fol.eq.1)THEN	!spring
							if(leafout.eq.0)leafout=yearday
							multtl=1.
							multtf=0.
						ELSE			                !summer
							multtl=0.
							multtf=0.
						ENDIF
					ENDIF
			
					IF(yearday.ge.200)THEN	
						max_fol=0.
						multtl=0.
					ENDIF 

					If(((yearday.ge.200).and.(ma_AirT.lt.p(13))).or.((yearday.ge.200).and.(leafin.gt.0)))THEN		!drop leaves
						multtf=1.
						if(leafin.eq.0)leafin=yearday+9
					ENDIF
				endif 
					
				if (decidflag.eq.0)then
					multtl = 1
					multtf = 1
					p(14)=1
					if(yearday.le.p(25))gdd(1)=0.
					gdd(1)=gdd(1)+0.5*max(maxt(i)+mint(i),0.0)
				endif
				if(decidflag.eq.1)then	
					tadj = 1
					tadj2=1
				else
					!if(yearday.gt.p(34))then ! p(33) and p(34) are now fed into photosynth
						tadj =max(0.0,min(1.0,(p(33)/maxt(i))))
						tadj2 =min(1.0,max(0.0,maxt(i)/40))
					!endif
					!tadj = 1
					!tadj2=1
					
				endif
				
				if ((yearday.gt.1).and.(yearday.lt.2)) gdd(2)=0
				
				gdd(2)=min(p(27),max(gdd(2)+(maxt(i)+mint(i))/2.,0.0))
				
				LMA = P(24)
				LAI=max(0.001,Cf/LMA) 

				laimeas(1)=bioData(i,indexBioLAI)		
				laimeas(2)=bioData(i,indexBioLAIe)
				if((decidflag.eq.0).and.(laimeas(1).lt.1))then
					laimeas(1)=-999
					laimeas(2)=-999
				endif
				GDaily=0
				GDaily2=0
				GcDaily=0
				GcDaily2=0
				ETDaily=0
				ETmeasDaily=0
				DrespDaily=0
				RaDaily=0
				RhLitDaily=0
				Rh1Daily= 0
				Rh2Daily=0
				Rh3Daily=0
				RrootDaily=0
				RsoilModDaily=0
				ralabtoDaily=0
				ralabfromDaily=0
				NeeDaily=0
				NeeDailyMeas=0
				radDaily=0
				fAparDaily=0
				precipDaily=0
				
				Ca=metData(i,1,indexMETco2)  		! ppm
				If(Ca.lt.100)Ca=358	! may be no data in Ca driver data
				
				neemeasDailyNight=0
				neemeasDailyDay=0
				neemodDailyNight=0
				neemodDailyDay=0
				
			hourloop: do j = 1,subDaily
					
					GsubDaily = 0
					Dresp=0
					GcSubDaily=0
					ETsubDaily=0
					projectday = metData(i,j,indexMETProjectDay)	
					
					! assign met data for current hour (all MET data sould be filled apriori)
					rad = metData(i,j,indexMETpar)   		  ! this is PAR (g_filled) in e-6mol/m2/s
					ppfdsun=0
					ppfdshd=0
					airT = metData(i,j,indexMETtemp)    	! air temperature, degrees C
					VPD = metData(i,j,indexMETvpd) 
					soilT = metData(i,j,indexMETsoilT)
					
					! assign the observed flux data for the current hour to neemeas
					if ((fluxData(i,j,indexFLUXnee).gt.-999))then	! check quality control flags	
						neemeas(1)=fluxData(i,j,indexFLUXnee)*0.0432396*period		! e-6mol/m2/s convert to gC m-2 h-1
						! assign uncertainty to the current observation (values taken from Richardson et al. 2006) 
						neemeas(2)=fluxData(i,j,indexFLUXneeE)*0.0432396*period
					else
						neemeas(1)=-999
						neemeas(2)=1
					endif
					
						  				
					! *************************************************************************************************
					! Carbon fluxes
					! *************************************************************************************************
						LAIsun=0
						PPFDsun=0
						PPFDshd=0
						
						! this section of the code runs the phoyosynthetic subroutine
						! run this code only if it is currently daytime and leaves are on the trees
       						if(lai.gt.0.001)then
							if(rad.gt.0.5) then
								! assign sunlit and shaded fractions of total LAI
								LAIsun = AssignLAI(lai,xfang,yearday,lat,j,subDaily,rad,PPFDsun,PPFDshd)
								fAparDaily=fAparDaily+((PPFDsun+PPFDshd))
								
								waterStress=min(swc/droughtEdge,1.0)
								! sun leaf photosynthesis
								G=PhotoSynth(airT,PPFDsun,VPD,Ca,Nit,LAI,Vcmax*waterStress,EaVcmax,EdVcmax,EaJmax,EdJmax,SJmax,&
													&Rd,Rdt,VQ10,p(31),p(32),p(34),Gc)*(0.0432396*period)*tadj*gdd(2)/p(27)
                                ! gdd(2)/p(27) is the phenology of photosynthesis/Vcmax
                                ! note: it's necessity could do with some testing.

								Gc = Gc * 3600 * period
								GsubDaily = (G*LAIsun)
								GcSubDaily = (Gc*LAIsun)
								Dresp=Rdt*0.0432396*period
								GDaily2=GDaily2+G
								GcDaily2=GcDaily2+Gc
								
								! shade leaf photosynthesis
                                G=PhotoSynth(airT,PPFDshd,VPD,Ca,Nit,LAI,Vcmax*waterStress,EaVcmax,EdVcmax,EaJmax,EdJmax,SJmax,&
													&Rd,Rdt,VQ10,p(31),p(32),p(34),Gc)*(0.0432396*period)*tadj*gdd(2)/p(27)
								Gc = Gc * 3600 * period
								GsubDaily = GsubDaily+ (G*(LAI-LAIsun))
								GcSubDaily = GcSubDaily+ (Gc*(LAI-LAIsun))
								Dresp=Dresp+Rdt*0.0432396*period
								
								ETsubDaily=ETsubDaily+GcSubDaily
								
								GDaily = GDaily + GsubDaily
								DrespDaily=DrespDaily+Dresp
								GcDaily=GcDaily+GcSubDaily
								ETDaily(1)=ETDaily(1)+ETSubDaily
								ETmeasDaily(1)=ETmeasDaily(1)+fluxData(i,j,indexFLUXlegf)
								
								if (fluxData(i,j,indexFLUXle).gt.0)then
									ETmeasDaily(2)=ETmeasDaily(2)+fluxData(i,j,indexFLUXle)
									ETmeasDaily(3)=ETmeasDaily(3)+fluxData(i,j,indexFLUXleE)
								         ETdaily(2)=ETdaily(2)+ETsubDaily
								        endif
							end if
						END if
						! Note, all G in umols/m2/s
							if(projectday.eq.180)then
							projectday=projectday
						endif
	
								
						TrateRoot=0.5*exp(p(29)*soilT)
						Rroot=(10**p(18))*Cr*TrateRoot*period
						
						Trate=0.5*exp(p(10)*airT) 
						RhLit = (10**p(8))*Clit*Trate*period
						
						! respiration when carbon is moved to or from the labile carbon pools
						ralabfrom=0!(10**p(15))*Clab*p(16)*multtl*Trate*decidflag
						ralabto=0!(1.-p(14))*(10**p(5))*Cf*p(16)*multtf*Trate*decidflag
						ralabfromDaily=ralabfromDaily+ralabfrom
						ralabtoDaily = ralabtoDaily+ralabto
						
						! calculate autotrophic respiration
						Ra = Dresp+ ralabfrom + ralabto+Rroot +P(2)*(GsubDaily-Dresp)
						!Ra= P(2)*GDailyPrevious        ! autotrophic respiration is coupled to GPP though the previous days assimilation
						!Ra = Ra+Dresp+ Rroot
						
						! calculate heterotrophic respiration
						TrateS=0.5*exp(p(28)*soilt)
						Rh1=(10**p(9))*CsomPools(1)*TrateS*tadj2*period	
						Rh2=(10**p(26))*CsomPools(2)*TrateS*tadj2*period       
						Rh3=(10**p(44))*CsomPools(3)*TrateS*period       
						
						! add these hourly values to the daily totals
						RaDaily = RaDaily+Ra
						RhLitDaily=RhLitDaily+RhLit
						Rh1Daily=Rh1Daily+Rh1
						Rh2Daily=Rh2Daily+Rh2
						Rh3Daily=Rh3Daily+Rh3
						
						RrootDaily=RrootDaily+Rroot
							
						if(rad.le.0.5)GsubDaily = 0 	! i don't know why i've put this here!

						! calculate the net ecosystem exchange by summing respiration and assimilation
						nee = Ra+RhLit+Rh1+Rh2+Rh3-GsubDaily
						neeDaily = neeDaily+nee
                                                
                                                ! daily sums
						radDaily=radDaily+rad
                                                precipDaily=precipDaily+metData(i,j,indexMetPrecip)
						
						! sum up the observed hourly NEE to daily, monthly and annual
						neeDailyMeas=neeDailyMeas+(fluxData(i,j,indexFLUXneegf))*(0.0432396*period)
						
						iNEE(1) = iNEE(1) + nee
						iNEEmeas(1)=iNEEmeas(1)+(fluxData(i,j,indexFLUXneegf))*(0.0432396*period)
						
						if(fluxData(i,j,indexFLUXnee).gt.-999) then	! annual NEE constraint non gap filled 
							iNEE(2) = iNEE(2) + nee
							iNEEmeas(2)=iNEEmeas(2)+(fluxData(i,j,indexFLUXnee))*(0.0432396*period)
						endif
					if(longTerm.eq.0)then
						if((mod(yearday,30.).ne.0).and.(fluxData(i,j,indexFLUXnee).gt.-999))then		! 30 day Nee constraint
							iNee(3) = iNee(3)+nee
							iNEEmeas(3)=iNEEmeas(3)+(fluxData(i,j,indexFLUXnee))*(0.0432396*period)
						endif
		                        endif
						! anything with an 'i' before it is an annual cumulative variable 
						iGPP = iGPP + GsubDaily
						iRa = iRa + Ra
						iDresp=iDresp+Dresp
						iRh = iRh + Rh1 + Rh2+Rh3+RhLit
						iRh1=iRh1+Rh1
						iRh2=iRh2+Rh2
						iRh3=iRh3+Rh3
						iRhLit=iRhLit+RhLit
						
						iRroot=iRroot+Rroot
						
						xx = Rh1+Rh2+Rh3+RhLit+Rroot
						RsoilModDaily=RsoilModDaily+xx
						iRsoil(1) = iRsoil(1) + xx

					! get integrated day and night time NEE
					if ((i.ge.stdaycal).and.(i.le.ndaycal)) then
						if (neemeas(1).gt.-999) then
							if (dayflag(i,j).eq.0) then
								neemeasDailyNight(1)=neemeasDailyNight(1)+neemeas(1)
                                                                neemeasDailyNight(2)=neemeasDailyNight(2)+neemeas(2)
                                                                neemodDailyNight(1)=neemodDailyNight(1)+nee
							endif
							if (dayflag(i,j).eq.1) then
								neemeasDailyDay(1)=neemeasDailyDay(1)+neemeas(1)
                                                                neemeasDailyDay(2)=neemeasDailyDay(2)+neemeas(2)
                                                                neemodDailyDay(1)=neemodDailyDay(1)+nee
							endif
						endif
					
						tmp=0
						tmp2=0
						do k=1,3
							if (rsoilmeas(k,1).gt.-999) then
								tmp=tmp+((((rsoilmeas(k,1)))-(bSoilMeas(k)*xx))/(rsoilmeas(k,2)))**2
								tmp2=tmp2+1
							endif
						enddo
						if (tmp2.gt.0)then
							if (dayflag(i,j).eq.0) then 
								err(13,1) = err(13,1)+tmp/tmp2
								countD(13)=countD(13)+1
							endif
							if (dayflag(i,j).eq.1) then
								err(14,1) = err(14,1)+tmp/tmp2
								countD(14)=countD(14)+1
							endif
						endif
						
					endif 
				

					if (iter.eq.endIteration) then  ! save the hourly data for output after inner loop
						
						innerRunOutSubDaily(innerRun,i,j,:) = (/metData(i,1,1),yearday,GsubDaily,&
                                                        &(fluxData(i,j,indexFLUXgppgf)*(0.0432396*period)),& !4
							&Ra,RhLit,Rh1,Rh2,Rh3,(fluxData(i,j,indexFLUXregf)*(0.0432396*period)),& !10
							&nee,NEEmeas(1),& !12
							&xx,rsoilmeas(1,1),LAIsun,LAI-LAIsun,metData(i,j,indexMETsoilT),airT,ralabto,ralabfrom,& !20
	 						&iGPP,iRh,iRa,iRsoil(1),iNee(1),iNee(2),ppfdsun,rad,G,Gc,vpd/) !31
														
					endif

				END DO hourloop
					GDailyPrevious=GDaily
	
					! calculate the day and night time NEE flux errors
					if ((i.ge.stdaycal).and.(i.le.ndaycal)) then
						if (neemeasDailyNight(1).ne.0) then
						        err(1,1) = err(1,1)+(((neemeasDailyNight(1)-neemodDailyNight(1))/(neemeasDailyNight(2)))**2)
                                                        countD(1)=countD(1)+1
						endif
						if (neemeasDailyDay(1).ne.0) then
						        err(2,1) = err(2,1)+(((neemeasDailyDay(1)-neemodDailyDay(1))/(neemeasDailyDay(2)))**2)
                                                        countD(2)=countD(2)+1
                                                endif
					endif
					
					! calculate the daily LE flux errors
					if ((i.ge.stdaycal).and.(i.le.ndaycal)) then
						if (ETmeasDaily(2).ne.0) then
						        err(19,1) = err(19,1)+(((ETmeasDaily(2)-ETDaily(2))/(ETmeasDaily(3)))**2)
                                                        countD(19)=countD(19)+1
						endif
					endif
					
						! calculate the temperature rates to be used for decomposition and respiration
						TrateDaily=0.5*exp(p(11)*(0.5*(maxt(i)+mint(i))))
						TrateDailyS=0.5*exp(p(41)*(0.5*(maxval(soilTemp(i,1:24))+minval(soilTemp(i,1:24)))))
						
						! Calculate the transfer of Litter from the litter pool to the fast soil pool	
						Dlit = (10**p(1))*Clit*TrateDaily

						! Set transfer rate between soil pools
						 if(numSoilPools.ge.2)then	
						        D1 = (p(35))*Rh1Daily !TrateDailyS	
						        if(numSoilPools.eq.3)then
							        D2 = (p(45))*Rh2Daily !TrateDailyS	
						        endif
					        endif	
						iD1=iD1+D1
						iD2=iD2+D2
						iDlit=iDlit+Dlit
						
						! Daily allocation
						npp = GDaily-DrespDaily
                                                if(GDaily.gt.DRespDaily)then
                                                        npp=npp-P(2)*(GDaily-DRespDaily)	
						endif
						
						if ((multtf.gt.0).and.(decidflag.gt.0))then
							Atolab = (1.-p(14))*(10**p(5))*Cf	!*(1.-p(16))*TrateDaily	
						else
							Atolab =0
						endif

						if(multtl.gt.0)then	
!						Afromlab = (10**p(15))*Clab*(1.-p(16))*TrateDaily*decidflag
						Afromlab=(10**p(15))*Clab*decidflag ! simplifying the leaf allocation routine here.
							if(npp.gt.0)then	
								Af= (npp*p(3)*multtl)+Afromlab	
								npp = npp-(npp*p(3)*multtl)		! allocate to foliage
							else
								Af=Afromlab
							endif
						else
							Af=0
							Afromlab=0
						endif
						
                                                if (npp.gt.0)then					
							Ar= npp*p(4)								! allocate to roots
							Aw=(1-p(4))*npp							! allocate to wood
						else
							Ar=0
							Aw=0
						endif
						
						! litterfall...leaf, wood, roots
						if(multtf.gt.0)then
							if(lai.le.0.5)then	! leaves just drop if there are few left
								Lf(1) =Cf
							else
								Lf(1) = (10**p(5))*Cf*p(14)*multtf
							endif
						endif
						
						Lw = (10**p(6))*Cw
						Lr = (10**p(7))*Cr
						
						!Daily Pools:
						Cf = Cf + Af - Lf(1) - Atolab - ralabtoDaily
							if(Cf.lt.0)then
								Cf=0
							endif	

						Cw = Cw+ Aw - Lw		
							if(Cw.lt.0)then
								Cw=0
							endif						
						Cr =Cr+ Ar - Lr-RrootDaily	
							if(Cr.lt.0)then
								Cr=0
							endif						
													
						Clit =Clit + Lf(1) + Lr - RhLitDaily - Dlit
							if(Clit.lt.0)then
								Clit=0
							endif						
								
						CsomPools(1) = CsomPools(1)+ Dlit -D1- Rh1Daily +Lw	
							if(CsomPools(1).lt.0)then
								CsomPools(1)=0
							endif	
					
						CsomPools(2) = CsomPools(2)+D1-D2 - Rh2Daily 	
							if(CsomPools(2).lt.0)then
								CsomPools(2)=0
							endif	
					
						CsomPools(3) = CsomPools(3)+D2 - Rh3Daily 	
							if(CsomPools(3).lt.0)then
								CsomPools(3)=0
							endif
	
						Clab=Clab+Atolab-Afromlab-ralabfromDaily	
							if(Clab.lt.0)then
								Clab=0
							endif						

						Lf(2)=Lf(2)+Lf(1)
						
						!Evaluate Daily:
						Csom=sum(CsomPools)
					        
					        ! daily soil water content
					        swc=soilWaterContent(swc,precipDaily,ETdaily(1),swhc,p(17),drainage,runoff) 
					
                                      if ((i.ge.stdaycal).and.(i.le.ndaycal)) then
						
						if (laimeas(1).gt.-999) then
							err(3,1) = err(3,1)+((laimeas(1)-lai)/laimeas(2))**2
							countD(3)=countD(3)+1
						endif
						if (cwmeas.gt.-999)  then
							! record first and last to catch trend
							if (cwMeasFirstLast(1).lt.0)then
								cwMeasFirstLast(1)=cwmeas
								cwModFirstLast(1)=cw
							endif
							cwMeasFirstLast(2)=cwmeas
							cwModFirstLast(2)=cw
														
							! get error for total amount
							err(10,1) = err(10,1)+((cwmeas-cw)/(cwmeasE))**2
							countD(10)=countD(10)+1
							
   							lastvalueCwMeas=cwmeas
							lastvalueCwMod=cw
							               
						endif
						
						! Error for wood carbon increment
                                                if (cwmeasInc.gt.-999)  then
                        				cwInc=cw-cwPreviousYear				
							! get error for total amount
							err(4,1) = err(4,1)+((cwmeasInc -cwInc)/(cwmeasIncE))**2
							countD(4)=countD(4)+1
						endif
                                                 ! check tehe Csom sums match total Csom (prevents consistent biases)
                                                 if (soilTotCmeas.gt.0)then
                                                       soilTotCmeas=bioData(i,indexBioSoilTotC)
                                                       soilTotCmeasE=bioData(i,indexBioSoilTotCe)
	                                               err(28,1)=err(28,1)+((soilTotCmeas-Csom)/(soilTotCmeasE))**2
						       CountD(28)=CountD(28)+1
					        endif
			
						if (litterfallmeas(1).gt.0) then
							err(5,1) = err(5,1)+((litterfallmeas(1)-Lf(2))/(1.5*litterfallmeas(2)))**2
							countD(5)=countD(5)+1
						endif
						
						if(decidflag.eq.1)then
							if (((yearday.eq.365.).and.(leafoutmeas(1).gt.0)).or.((i.eq.ndaycal).and.(leafoutmeas(1).gt.0))) then
								err(11,1) = err(11,1)+((leafoutmeas(1)-leafout)/(leafoutmeas(2)))**2
								countD(11)=countD(11)+1
							endif
	
							if (((yearday.eq.365.).and.(leafinmeas(1).gt.0)).or.((i.eq.ndaycal).and.((leafinmeas(1).gt.0)))) then
								err(12,1) = err(12,1)+((leafinmeas(1)-leafin)/(leafinmeas(2)))**2
								countD(12)=countD(12)+1
							endif
						endif
						
						if (((yearday.eq.365.).and.(iRsoilmeas.gt.100)).or.((i.eq.ndaycal).and.(iRsoilmeas.gt.100))) then	! annual non gap filled  soil Respiration measurements
							err(8,1) = err(8,1)+((iRsoilmeas-iRsoil(2))/(0.25*(iRsoilmeas)))**2
							CountD(8)=CountD(8)+1
						endif
						 
						if (((mod(yearday,30.).eq.0)).and.(iNeemeas(3).ne.0.)) then	! monthly non.gap.filled measurements
							! some sites have very small NEE
							err(17,1) = err(17,1)+((iNeemeas(3)-iNee(3))/(10+0.15*abs(iNeemeas(3))))**2
							CountD(17)=CountD(17)+1
						endif
						
						
						if ((yearday.eq.365.).or.(i.eq.ndaycal)) then
							
							! carbon in roots relative to estimated initial value
							err(7,1) = err(7,1)+((Cr-p(19))/(p(19)*0.2)**2
							countD(7)=countD(7)+1
							
							! carbon in litter relative to estimated initial value
							err(6,1) = err(6,1)+((Clit-p(21))/(p(21)*0.2))**2
							countD(6)=countD(6)+1
							
							! carbon in litter turnover time
							err(23,1) = err(23,1)+(((Clit/(iRhLit))-4)/3)**2
							countD(23)=countD(23)+1
							
							! proportion of soil respiration contributed by autotrophic Resp.
							err(15,1) = err(15,1)+((0.33-(iRroot/(iRsoil(1))))/(0.35*(0.33)))**2
							CountD(15)=CountD(15)+1
						
							! annual non gap filled  (estimated as ~0.25*iNeemeas(2) by Barr et al. for NOAA synth)
							if(NOAA.ne.1)then
								! some sites (PFa) have very low NEE, which can generate large cost when scaling by error	
								err(16,1) = err(16,1)+((iNeemeas(1)-iNee(1))/(40+0.2*(iNeemeas(1))))**2
							else
								if(iNeemeas(2).ne.0)then	! some sites with very small NEE
										! PFa monthly is so small can't set large intercept of 40
										err(16,1) = err(16,1)+((iNeemeas(2)-iNee(2))/(40+0.2*abs(iNeemeas(2))))**2
								else
									CountD(16)=CountD(16)-1
								endif
							endif
							CountD(16)=CountD(16)+1
						
							! Cf reality error check (should be zero at end of year)
							if(decidflag.eq.1)then
								err(18,1) = err(18,1)+Cf
								CountD(18)=CountD(18)+1
							endif
							
							! SOM turnover time errors (these turnover times are mass weighted to get the average for each pool)
								if(numSoilPools.eq.3)then
									! carbon in SOM1 turnover time (this is the Microbial pool)
									err(24,1) = err(24,1)+(((CsomPools(1)/(iRh1+iD1))-1.5)/1.2)**2
									countD(24)=countD(24)+1
		
									! carbon in SOM2 turnover time (This is the slow pool)
									err(25,1) = err(25,1)+(((CsomPools(2)/(iRh2+iD2))-58)/30)**2
									countD(25)=countD(25)+1
									
									! carbon in SOM3 turnover time (This is the fast pool)
									err(26,1) = err(26,1)+(((CsomPools(3)/iRh3)-1354)/450)**2
									countD(26)=countD(26)+1
									
								else if(numSoilPools.eq.2)then
									! carbon in SOM1 turnover time (this is the O horizon)
									err(24,1) = err(24,1)+(((CsomPools(1)/iRh1+iD1)-58)/30)**2
									countD(24)=countD(24)+1
		
									! carbon in SOM2 turnover time (this is the A and B horizon)
									err(25,1) = err(25,1)+(((CsomPools(2)/iRh2+iD2)-545)/250)**2
									countD(25)=countD(25)+1
									
								else        ! carbon in SOM1 turnover time
									err(24,1) = err(24,1)+(((CsomPools(1)/iRh1)-473)/235)**2
									countD(24)=countD(24)+1
								endif
							 
							! Lwood error 
							err(20,1)=err(20,1)+((40-iLw)/(0.2*40))**2
							CountD(20)=CountD(20)+1
						endif
						
						
					endif 
					
					
					if(i.eq.nday)then	! test reality over whole period (this changed from V4, where reality was tested at end ndaycal
						! Carbon Pool Reality check - no pools should be emptying
							if(NOAA.eq.0)then		
									RealityErr =RealityErr+ (&
											&max((P(19))-Cr,0.0)+&		! pools should not end below their starting value
											&max((P(20))-Cw,0.0)+&
											&max((P(21))-Clit,0.0)+&
											&max((P(22))-(CsomPools(1)),0.0)+&
											&max((P(42))-(CsomPools(2)),0.0)+&
											&max((P(43))-(CsomPools(3)),0.0)+&
											&max((P(23))-Clab,0.0)) 
											
										RealityErr = RealityErr - &				! or grow by more than 50% over simulation period
											&min(0.,(2.5*P(19))-Cr)-&
											&min(0.,(1.5*P(20))-Cw)-&
											&min(0.,(2*P(21))-Clit)-&
											&min(0.,(1.5*P(22))-CsomPools(1))-&
											&min(0.,(1.5*P(42))-CsomPools(2))-&
											&min(0.,(1.5*P(43))-CsomPools(3))-&
											&min(0.,(1.5*P(23))-Clab)
							endif
							if(NOAA.eq.1)then
								if(decidflag.eq.1)then
									RealityErr =RealityErr+ (&
											&max((0.9*P(19))-Cr,0.0)+&		! pools should not end below their starting value
											&max((P(20))-Cw,0.0)+&
											&max((P(21))-Clit,0.0)+&
											&max((0.95*P(22))-(CsomPools(1)),0.0)+&
											&max((0.95*P(42))-(CsomPools(2)),0.0)+&
											&max((P(43))-(CsomPools(3)),0.0)+&
											&max((P(23))-Clab,0.0)) 
											
										RealityErr = RealityErr - &				! or grow by more than 50% over simulation period
											&min(0.,(2.5*P(19))-Cr)-&
											&min(0.,(2.5*P(20))-Cw)-&
											&min(0.,(2*P(21))-Clit)-&
											&min(0.,(1.5*P(22))-CsomPools(1))-&
											&min(0.,(1.5*P(42))-CsomPools(2))-&
											&min(0.,(1.5*P(43))-CsomPools(3))-&
											&min(0.,(1.1*P(23))-Clab)
							        else
							       			RealityErr =RealityErr+ (&
											&max((0.8*P(19))-Cr,0.0)+&		! pools should not end below their starting value
											&max((P(20))-Cw,0.0)+&
											&max((P(21))-Clit,0.0)+&
											&max((0.95*P(22))-(CsomPools(1)),0.0)+&
											&max((0.95*P(42))-(CsomPools(2)),0.0)+&
											&max((P(43))-(CsomPools(3)),0.0)+&
											&max((0.8*P(12))-Cf,0.0)) 	! 0.7 to allow for some interannual variability
											
					 					RealityErr = RealityErr - &				! or grow by more than 50% over simulation period
											&min(0.,(2.5*P(19))-Cr)-&
											&min(0.,(2*P(20))-Cw)-&
											&min(0.,(1.25*P(21))-Clit)-&
											&min(0.,(1.5*P(22))-CsomPools(1))-&
											&min(0.,(1.25*P(42))-CsomPools(2))-&
											&min(0.,(1.25*P(43))-CsomPools(3))-&
											&min(0.,(1.1*P(12))-Cf)
							        
								endif
							endif
						endif
					
					
					! prevent SOM pools having transient dynamics by testing each year.
					if ((yearday.eq.365.).or.(i.eq.ndaycal)) then
					
								if(numSoilPools.eq.3)then ! 3 pool model
									! 1. The microbial soil carbon pool as 1-3% of the total pool
									err(21,1)=err(21,1)+((0.02*Csom-CsomPools(1))/(0.01*Csom))**2
									CountD(21)=CountD(21)+1
									
									! 2. The slow SOC pool (equivalent to the fast pool when using two pool model)
									err(22,1)=err(22,1)+((p(42)+(20*(countD(22)-8))-CsomPools(2))/(p(42)*0.2))**2
									CountD(22)=CountD(22)+1
									! 3. The passive SOC pool should not change greatly over time
									err(27,1)=err(27,1)+((p(43)-CsomPools(3))/(p(43)*0.2))**2
									CountD(27)=CountD(27)+1
									
								else if(numSoilPools.eq.2)then ! 2 pool model
									err(21,1)=err(21,1)+((p(22)-CsomPools(1))/(p(22)*0.2))**2
									CountD(21)=CountD(21)+1
									err(22,1)=err(22,1)+((p(42)+(50*(countD(22)-8))-CsomPools(2))/(p(42)*0.2))**2
									CountD(22)=CountD(22)+1
								else ! 1 pool model
									err(21,1)=err(21,1)+((p(43)-CsomPools(1))/(p(43)*0.2))**2
									CountD(21)=CountD(21)+1
								endif
					endif 
		
					if (cwmeas.gt.-999)  then
							lastvalueCwMeas=cwmeas
							lastvalueCwMod=cw
					endif
						
					if (iter.ge.endIteration) then  ! save for output after inner loop
							fAparDaily=fAparDaily/radDaily
							
						pred(InnerRun,i,:) = (/metData(i,1,1),yearday,GDaily,iGPP,& !4
							&RaDaily,iRa,Rh1Daily,Rh2Daily,Rh3Daily,iRh,& !10
							&NeeDaily,iNee(1),iNee(2),&
							&Af,Aw,Ar,Atolab,Afromlab,Lf(1),Lw,Lr,D1,D2,& !23
							&Cf,Cr,Clab,Clit,Csom,CsomPools(1),CsomPools(2),CsomPools(3),gdd(1),gdd(2)/P(27),&
							&max_fol,multtf,multtl,Clit/iRhLit,& !37
							&CsomPools(1)/iRh1,CsomPools(2)/iRh2,CsomPools(3)/iRh3,neeDailyMeas,& !41
							&lai,laimeas(1),laimeas(2),iLw,Cw,Cw-p(20),& !47
							&cwmeas,lf(2),litterfallmeas(1),litterfallmeas(2),&!51
							&RrootDaily,rsoilmeas(1,1),RrootDaily/RsoilModDaily,&
							&iRroot/iRsoil(1),& !55
							&iNEEmeas(1),iNEEmeas(2),iRsoil(2),iRsoilmeas,leafin,leafinmeas(1),leafinmeas(2),& !62
							&leafout,leafoutmeas(1),iRsoil(1),GcDaily2,GDaily2,ETDaily(1),Ca,RhLitDaily+Rh1Daily+Rh2Daily+Rh3Daily,& !70
                                                        &cwmeasInc,cwInc,ETmeasDaily(1),swc,drainage,runoff,precipDaily,&         ! 77
                                        &neemeasDailyDay(1),neemodDailyDay(1),neemeasDailyNight(1),neemodDailyNight(1)/)          ! 81
						
							if(iter.eq.endIteration)innerRunOutDaily=pred
							
					endif
			
			
					if (litterfallmeas(1).gt.-999) Lf(2)=0
					
					if((mod(yearday,30.).eq.0))then		! 30 day Nee constraint reset
							iNee(3) = 0
							iNEEmeas(3)=0
					endif
					 
			END DO timeloop
		
			annualNEE(year)=iNEE(1) ! Save from final year
			annualGPP(year)=iGPP
			annualRa(year)=iRa
			annualRh(year)=iRh
			
			! error 9 is long term increment, no average error, just calculate here.
			err(9,1) =(((cwMeasFirstLast(2)-cwMeasFirstLast(1))&	! Cw  increment
									&-(cwModFirstLast(2)-&
									&cwModFirstLast(1)))/&
									&(0.1*(cwMeasFirstLast(2)-cwMeasFirstLast(1))))**2
			
			

                        ! calculate the total error for the current parameter set
                        ! and data constraints applied
toterr=TotalErrorV4bayes(err,RealityErr,rep,numConstraints,constraints,numSoilPools,toterrAll,countD,nparams,boundsP,P)

				if (iter.le.q) then
				
					de = toterr-besterr
					if (de<0) then 
					      ans=1
					else
					      ans=0
					end if
									
					!Apply the metropolis function....
					!call metrop(de,annealtemp,ans)
					call random_number(ran)
					expo=-de/annealtemp
					if (expo.gt.88) expo=88
					if (ran<exp(expo)) then	
					      ans = 2
					end if
					! end metropolis
									
					if ((toterr.le.allbest).and.(toterr.ge.0)) then
						if ((acceptflag.eq.0))then
							allbest=toterr
							bestp=p
							laststep=iter
						endif
					endif
				
					if (ans.eq.0) then
						stepflag = 0
							if ((iter.gt.(r))) then
								incP=incP*(0.999)
							endif
					endif						
					if ((ans.ge.1).and.(toterr.ge.0)) then
						besterr=toterr
						
						acc(innerRun)=acc(innerRun)+1
						if ((iter.gt.(r))) then
							oldp=p
							incP=incP*(1.002) !	fror 23% acceptance rate
						endif
						
						if ((ans.eq.1).and.(stepflag.ne.-1)) then
							stepflag = 1 
						else 
							stepflag = 0
						endif
					endif
				endif 

		
			parameters(1,countTotalIterations,:) = P(:)
			
			error(1,countTotalIterations,1) = toterr
			error(1,countTotalIterations,2) = besterr
			error(1,countTotalIterations,3) = allbest	
		
			countTotalIterations=countTotalIterations+1

			! this prints habitualy to screen / can't do in parallel
if (((outerRun.ge.0).or.(iter.eq.q)).and.&
&((iter.le.50).or.(mod(int(iter),1000).eq.0).or.(iter.eq.r).or.(iter.eq.q-1)).and.(iter.le.q)) then 

!if(numSoilPools.eq.3)then
	
	write(*,"(1i12.0,28f7.2,2f8.1,2f4.1)") iter,err(1,1),err(2,1),err(19,1),err(3,1),err(4,1),err(10,1),err(5,1),&
				&err(20,1),err(6,1),err(7,1),err(13,1),&
				&err(14,1),err(8,1),err(11,1),err(12,1),RealityErr,err(21,1),&
				&err(22,1),err(27,1),err(28,1),err(23,1),err(24,1),err(25,1),err(26,1),err(15,1),err(16,1),err(17,1),err(18,1),&
					&toterr,allbest,annealtemp,floatingAcc

endif

                        		
if ((iter.eq.q).or.(iter.eq.r-1))then
		write(*,*) "iteration   neeNight neeDay  LE     LaiE  CwIncErr CwE  LfErr  LwErr  ClitErr CrE&
			& rSoilEN rSoilED iRSoile SprinE FallE RealitE SOM1e SOM2e  SOM3e  SOMallE&
				& LitTO SOM1tO SOM2tO SOM3tO RootRPe iNeeE &
			&iNEEeM CfE   totE   allBest anneal Acc"
endif
							
			floatingIter = iter+0.01
			floatingAcc = acc(innerRun)+0.01
			floatingAns = ans+0.01
			floatingStepflag = Stepflag+0.01

			! here we save the parameters of the first and second exploration to file ....
			! and then print all innerRun parameters after the inner loop has finished
						
							if (iter.eq.r) then
								innerRunParameters(1,innerRun,:) = bestP(:)
								innerRunIncP(1,innerRun,:) = incP(:)
								innerRunBoundsP(1,innerRun,:,1) =boundsP(:,1)
								innerRunBoundsP(1,innerRun,:,2) = boundsP(:,2)
							end if
							if (iter.eq.endIteration) then
								innerRunParameters(2,innerRun,:) = bestP(:)
								innerRunIncP(2,innerRun,:) = incP(:)
								innerRunBoundsP(2,innerRun,:,1) =boundsP(:,1)
								innerRunBoundsP(2,innerRun,:,2) = boundsP(:,2)
			
                        					acc(innerRun) = 0
								stepflag = 0
								
								prange(:,1)=P(:)
								prange(:,2)=P(:)
								
								if(outerRun.eq.numOuterRuns)then
									qerr(:)=max(0.0001,err(:,1))
									! for data streams with just one meas, normalization does not apply
									if (qerr(6).lt.1)qerr(6)=1
									if (qerr(7).lt.1)qerr(7)=1
                                                                        if (qerr(8).lt.1)qerr(8)=1		! added for cumRsoil constraint to keep consistent with data
									if (qerr(9).lt.1)qerr(9)=1
									if (qerr(10).lt.1)qerr(10)=1
                                                                        if (qerr(15).lt.1)qerr(15)=1
                                                                        if (qerr(16).lt.1)qerr(16)=1	! added for annual NEE constraint (few data points, can get if constrained to iNEE alone)
                                                                        if (qerr(20).lt.1)qerr(20)=1
									if (qerr(21).lt.1)qerr(21)=1
									if (qerr(22).lt.1)qerr(22)=1
									if (qerr(23).lt.1)qerr(23)=1
									if (qerr(24).lt.1)qerr(24)=1
									if (qerr(25).lt.1)qerr(25)=1
									if (qerr(26).lt.1)qerr(26)=1
									if (qerr(27).lt.1)qerr(27)=1
									if (qerr(28).lt.1)qerr(28)=1
									
									err(:,2)=err(:,1)/qerr(:)
								endif
							endif
	
        			if (iter.ge.endIteration) then
					! reset for Chi/sqr testing....
					err(:,2)=err(:,1)/qerr(:)
				endif

				if (iter.ge.endIteration) then
				if ((acc(innerRun).ge.explore).or.(outerRun.lt.numOuterRuns).or.(iter.ge.(endIteration+exploreLength))) then ! if we have gotten to the end, and found the parameters, and then we exit...
					exit							! if we don't accept explore parameters within 10000 runs then we leave anyway. 
				endif
				
				flag=0
				countExplore=countExplore+1
				
				!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
				! Now in SEARCH STAGE
				!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
				
                                ! check if the current parameter set is acceptable based on chi-squared test 
				flag=posteriorChiSqTest(err,forest,rep,decidflag,RealityErr,numConstraints,constraints)
				
                                if (flag.eq.1)then

					acc(innerRun) = acc(innerRun) + 1
					accparm(acc(innerRun),innerRun,1:nparams)=p(1:nparams)
                                        accparm(acc(innerRun),innerRun,nparams+1)=toterrAll


					! adaptive step size algorithm for search stage
					! my own invention - so step wisely
					! will adjust step sizes dynamically to get a 25% (or whatever specified) acceptance rate
					! this lets the parameter range expand beyond the priors in the posterior exploration 
				
					tmp=acc(innerRun)
					tmp2=countExplore
					tmp=tmp/tmp2
					
					if (tmp.gt.acceptanceRate)then	! if more than x% of parameters are getting accepted, increase step size
						stepSize=stepSize*1.01
					else	! otherwise, decrease step size to increase acceptance rate
						stepSize=stepSize*0.99
					endif

					!auto scaling of prange
					prange(:,1)=min(prange(:,1),p(:))
					prange(:,2)=max(prange(:,2),p(:))

					! auto scaling in IncP
					incP=max((prange(:,2)-prange(:,1))*stepSize(:),abs(bestP(:))*0.00001)

					if ((acc(innerRun).le.100.0).and.(firstexplore.lt.1)) then
						acc(innerRun) = 1
						firstexplore=firstexplore+1
					endif
						
					if(mod(acc(innerRun),500).eq.0)then	
						write(*,*) "*****************Increasing Range************************"
						write(*,*)acc(innerRun), iter, (prange(:,2)-prange(:,1)),toterrAll
			
					endif
					
					cl(:,:,1)=max(cl(:,:,1),Pred(InnerRun,:,:))
					cl(:,:,2)=min(cl(:,:,2),Pred(InnerRun,:,:))
					
					posteriorFluxComponents(acc(innerRun),1:nyears)=annualNEE
					posteriorFluxComponents(acc(innerRun),(nyears+1):nyears*2)=annualGPP
					posteriorFluxComponents(acc(innerRun),(nyears*2+1):nyears*3)=annualRa
					posteriorFluxComponents(acc(innerRun),(nyears*3+1):nyears*4)=annualRh
					
					clHigh(innerRun,:,:)=cl(:,:,1)
					clLow(innerRun,:,:) = cl(:,:,2)

					oldp = p
				
				else
				! parameter set not accepted - decrease step size
						incP=incP*0.99
						
						tmp=acc(innerRun)
						tmp2=countExplore
						tmp=tmp/tmp2
					
						if (tmp.lt.0.225)then
							stepSize=stepSize*0.99
						endif
				endif
				
			end if	
			END DO mcloop

End Do


!***********************************************************************
!! here need to choose best parameter set and use for next outer run
!***********************************************************************
bestInnerRun=1

close(30)				
bestinnerRun=1
bestp=innerRunParameters(2,bestInnerRun,:)
P = bestP
incP = innerRunIncP(2,bestInnerRun,:)
boundsP(:,1)=innerRunBoundsP(2,bestInnerRun,:,1) 
boundsP(:,2)=innerRunBoundsP(2,bestInnerRun,:,2) 

print *, "Finished ...."
	print *, 'Site Name: ', forest
	print *, 'Decid (1)/Evergreen (0): ', decidflag
	print *, 'Rep: ', rep

! print final output corresponding to best parameter set
if(outerRun.eq.numOuterRuns)then

	write (filenum (1), *) decidflag
	write (filenum (2), *) rep
	write (filenum (3), *) jfunct
	write (filenum (4), *) numSoilPools
	
	
	filename = "/"//home//"/Results/CarboExtreme/FoBAAR/FoBAARbetaV5/"//forest//"/Data/"//forest//"_outputDaily_"//&
		&trim(adjustl(filenum(1)))//"_"//&
		&trim(adjustl(filenum(2)))//"_"//trim(adjustl(filenum(3)))//"_"//trim(adjustl(filenum(4)))//".csv"
	do i=1,nday
			if (i.eq.1) then !write headers on first day step of last run
				open(unit=26,file=filename,status='unknown')	! outputs

			endif
			write(26,*)(innerRunOutDaily(bestInnerRun,i,j), j=1,numDailyVariablesOut)
			
			if (i.eq.nday) then
				close(26)
			endif
	End Do			
	
	
	
	! print final output corresponding to best parameter set
	filename = "/"//home//"/Results/CarboExtreme/FoBAAR/FoBAARbetaV5/"//forest//"/Data/"//forest//"_outputSubDaily_"//&
			&trim(adjustl(filenum(1)))//"_"//trim(adjustl(filenum(2)))//"_"//&
			&trim(adjustl(filenum(3)))//"_"//trim(adjustl(filenum(4)))//".csv"
	do i=1,nday
			if (i.eq.1) then !write headers on first day step of last run
				open(unit=26,file=filename,status='unknown')	! outputs
			endif
		do j =1,subDaily		
			write(26,*)(innerRunOutSubDaily(bestInnerRun,i,j,k), k=1,numSubDailyVariablesOut)
		end do	
			if (i.eq.nday) then
				close(26)
			endif
	End Do			
	
	! print parameters used in each iteration of the MC3 simulation	
	filename1 = "/"//home//"/Results/CarboExtreme/FoBAAR/FoBAARbetaV5/"//forest//"/Data/parameterEvolution_"//&
				&trim(adjustl(filenum(1)))//"_"//trim(adjustl(filenum(2)))//"_"&
				&//trim(adjustl(filenum(3)))//"_"//trim(adjustl(filenum(4)))//".csv"
	do i=1,(q*(numOuterRuns+1)+exploreLength)
			if (i.eq.1) then !write headers on first day step of last run
				open(unit=26,file=filename1,status='unknown')	! parameters
			endif
	
	End Do		
	
	close(26)
	close(27)
	close(28)
	close(29)
	close(30)
	close(31)

	filename = "/"//home//"/Results/CarboExtreme/FoBAAR/FoBAARbetaV5/"//forest//"/Data/AccParams_"//trim(adjustl(filenum(1)))//"_"//&
	&trim(adjustl(filenum(2)))//"_"//trim(adjustl(filenum(3)))//"_"//trim(adjustl(filenum(4)))//".txt"
	open(unit=30,file=filename)
	write(30,*) "P1 P2 P3 P4 P5 P6 P7 P8 P9 P10 P11 P12 P13 P14 P15 P16 P17 P18 P19 P20 P21 P22 &
			&P23 P24 P25 P26 P27 P28 P29 P30 P31 P32 P33 P34 P35 P36 P37 P38 P39 P40 P41 P42"
	do i=1,acc(bestInnerRun)
		write(30,*) accparm(i,bestInnerRun,1:nparams)
	end do
	close(30)

        ! print accepted toterr on it's own
	filename = "/"//home//"/Results/CarboExtreme/FoBAAR/FoBAARbetaV5/"//forest//"/Data/TotalError_"//trim(adjustl(filenum(1)))//"_"//&
	&trim(adjustl(filenum(2)))//"_"//trim(adjustl(filenum(3)))//"_"//trim(adjustl(filenum(4)))//".txt"
	open(unit=30,file=filename)
	write(30,*) "TotErrAll"
	do i=1,acc(bestInnerRun)
		write(30,*) accparm(i,bestInnerRun,nparams+1)
	end do
	close(30)

	filename = "/"//home//"/Results/CarboExtreme/FoBAAR/FoBAARbetaV5/"//forest//"/Data/FoBAAR UCL_"//trim(adjustl(filenum(1)))//"_"//&
	&trim(adjustl(filenum(2)))//"_"//trim(adjustl(filenum(3)))//"_"//trim(adjustl(filenum(4)))//".txt"
	open(unit=32,file=filename)	
	write (32,*) "Random header"
	do j=1,nday
		write (32,*) clHigh(bestInnerRun,j,:)
	enddo
	close(32)

	filename = "/"//home//"/Results/CarboExtreme/FoBAAR/FoBAARbetaV5/"//forest//"/Data/FoBAAR LCL_"//trim(adjustl(filenum(1)))//"_"//&
			&trim(adjustl(filenum(2)))//"_"//trim(adjustl(filenum(3)))//"_"//trim(adjustl(filenum(4)))//".txt"
	open(unit=32,file=filename)
	write (32,*) "Random header"
	do j=1,nday
		write (32,*) clLow(bestInnerRun,j,:)
	enddo
	close(32)

	filename = "/"//home//"/Results/CarboExtreme/FoBAAR/FoBAARbetaV5/"&
                &//forest//"/Data/BestParams_"//trim(adjustl(filenum(1)))//"_"//&
	        &trim(adjustl(filenum(2)))//"_"//trim(adjustl(filenum(3)))//"_"//trim(adjustl(filenum(4)))//".txt"
	open(unit=30,file=filename)
	write (30,*) (bestP(i),i=1,nparams)
	close(30)
	
	filename = "/"//home//"/Results/CarboExtreme/FoBAAR/FoBAARbetaV5/"&
                &//forest//"/Data/PostFluxComponents_"//trim(adjustl(filenum(1)))//"_"//&
	        &trim(adjustl(filenum(2)))//"_"//trim(adjustl(filenum(3)))//"_"//trim(adjustl(filenum(4)))//".txt"
	open(unit=30,file=filename)
	do j=1,explore
	write (30,*) (posteriorFluxComponents(j,i),i=1,nyears*4)
	enddo
	close(30)	
	
endif

close(33)


if (decidflag.eq.1) then
	open(unit=33,file='/'//home//'/Results/CarboExtreme/FoBAAR/FoBAARbetaV5/'//forest//'/Data/&
		&initialRun_D_'//trim(adjustl(repChar))//'.csv',&
		&status='unknown')		
else
	open(unit=33,file='/'//home//'/Results/CarboExtreme/FoBAAR/FoBAARbetaV5/'//forest//'/Data/&
		&initialRun_E_'//trim(adjustl(repChar))//'.csv',&
		&status='unknown')		
endif

write (33,*) (bestP(i),i=1,nparams)

close(33)



ENDDO outer

ENDDO cost

ENDDO DECID_EVERGREEN


close(26)

!print execution time.
call ETIME(tarray, result) 
 print *, "Execution time (seconds)...."
              print *, tarray(1)	!user time in seconds
              print *, tarray(2) !system time in seconds     


END


!*************************************************************************
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!*************************************************************************


FUNCTION rnorm() RESULT( fn_val )

!   Generate a random normal deviate using the polar method.
!   Reference: Marsaglia,G. & Bray,T.A. 'A convenient method for generating
!              normal variables', Siam Rev., vol.6, 260-264, 1964.

IMPLICIT NONE
REAL  :: fn_val

! Local variables

REAL            :: u, sumx
REAL, SAVE      :: v, sln
LOGICAL, SAVE   :: second = .FALSE.
REAL, PARAMETER :: one = 1.0, vsmall = TINY( one )

IF (second) THEN
! If second, use the second random number generated on last call

  second = .false.
  fn_val = v*sln

ELSE
! First call; generate a pair of random normals

  second = .true.
  DO
    CALL RANDOM_NUMBER( u )
    CALL RANDOM_NUMBER( v )
    u = SCALE( u, 1 ) - one
    v = SCALE( v, 1 ) - one
    sumx = u*u + v*v + vsmall         ! vsmall added to prevent LOG(zero) / zero
    IF(sumx < one) EXIT
  END DO
  sln = SQRT(- SCALE( LOG(sumx), 1 ) / sumx)
  fn_val = u*sln
END IF
RETURN
END FUNCTION rnorm


! --------------------------------------------------------------------------------------------------


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


!!! Read the driver data from file
subroutine readObservedData(bioData,maxt,mint,fluxData,metData,Dayflag,soilTemp,longTerm)
! this routine will read in the driver data and calculate the soil temperature

use obsdrivers

implicit none

real :: fluxData(nday,subDaily,numColumnsFlux)
real :: metData(nday,subDaily,numColumnsMet)
real :: bioData(nday,numColumnsBio)
real :: maxt(nday),mint(nday)
real, intent(in) :: longTerm
real :: dayflag(nday,subDaily)
real :: soilTemp(nday,subDaily)

integer :: i,j,k

! DRIVERS

! Read in the met data
open(unit=26,file='/'//home//'/Data/CarboExtreme/FoBAAR/'//forest//'/metData2.csv',status='old')
! headers...
Read(26,*)
Read(26,*)
Read(26,*)
Read(26,*)

if (longTerm.eq.0)then
	! Read in the flux data
	open(unit=25,file='/'//home//'/Data/CarboExtreme/FoBAAR/'//forest//'/fluxData.csv',status='old')	
	Read(25,*)
	Read(25,*)
	Read(25,*)
	Read(25,*)
	 
	! Read in the biometric data
	open(unit=29,file='/'//home//'/Data/CarboExtreme/FoBAAR/'//forest//'/bioData2.csv',status='old')
	READ(29,*)
endif

bioData = -999
maxt = -999
mint = 999
  
! READ IN OBSERVATIONS AND DRIVERS

DO i=1,nday
	DO j = 1,subDaily
		Read(26,*)(metData(i,j,k),k=1,numColumnsMet) 
		if(metData(i,j,indexMETpar).gt.0)Dayflag(i,j)=1		! if filled PAR > 0, set dayflag to day 

                if (longTerm.eq.0)then
			Read(25,*)(fluxData(i,j,k),k=1,numColumnsFlux)
		endif		
		! calculate daily max and min temperatures
		if ((metData(i,j,indexMETtemp).lt.mint(i)).and.(metData(i,j,indexMETtemp).gt.-100)) then
			mint(i) = metData(i,j,indexMETtemp)
		endif
		
		if (metData(i,j,indexMETtemp).gt.maxt(i).and.(metData(i,j,indexMETtemp).gt.-100)) then
			maxt(i) = metData(i,j,indexMETtemp)
		endif
				
	END DO
                if (longTerm.eq.0)then
	
			Read(29,*)(bioData(i,k),k=1,numColumnsBio)
		endif		
	
END DO

close(26)

	if (longTerm.eq.0)then
		close(25)
		close(29)
	endif

end

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!




