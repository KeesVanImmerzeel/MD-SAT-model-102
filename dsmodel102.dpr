library dsmodel102;
  {-Stikstofuitspoeling vlgs. A. Tietema.
    ICG Rapport 99/2, maart 1999. }

  { Important note about DLL memory management: ShareMem must be the
  first unit in your library's USES clause AND your project's (select
  Project-View Source) USES clause if your DLL exports any procedures or
  functions that pass strings as parameters or function results. This
  applies to all strings passed to and from your DLL--even those that
  are nested in records and classes. ShareMem is the interface unit to
  the BORLNDMM.DLL shared memory manager, which must be deployed along
  with your DLL. To avoid using BORLNDMM.DLL, pass string information
  using PChar or ShortString parameters. }

{.$define test}

uses
  ShareMem,
  {$ifdef test} forms, {$endif} windows, SysUtils, Classes, LargeArrays,
  ExtParU, USpeedProc, uDCfunc,UdsModel, UdsModelS, xyTable, Math, DUtils, uError;

Const
  cModelID      = 102;  {-Key to this model (=unique-ID)}

  {-Mapping of dependent variable vector (=aantal te integreren snelheden)}
  cNrOfDepVar   = 3;    {-Length of dependent variable vector}

  cNatGWaanv    = 1;    {-Natuurlijke grondwateraanvulling (m/d}
  cNuitsp       = 2;    {-Uitspoeling (kg N/ha/jr)}
  cOpslgN       = 3;    {-Opslag van stikstof in de organische laag (kg N/ha;
                          geldt alleen voor bos) }
						  
  {-Aantal keren dat een discontinuiteitsfunctie wordt aangeroepen in de procedure met
    snelheidsvergelijkingen (DerivsProc)}
  nDC = 0;

  {***** Used when booted for shell-usage ***}
  cnRP    = 10; {-Nr. of RP-time-series that must be supplied by the shell in
                  EP[ indx-1 ].}
  cnSQ    = 0;  {-Nr. of point-time-series that must be supplied by the shell
                  in EP[ indx-1 ]. REM: point- sources niet aan de orde bij
                  stikstof-uitspoeling!}
  cnRQ    = 0;  {-Nr. of line-time-series that must be supplied
                  by the shell in EP[ indx-1 ]. REM: point- sources niet aan de
                  orde bij stikstof-uitspoeling!}

  {-Mapping of EP[cEP0]}
  cNrXIndepTblsInEP0 = 10;  {-Nr. of XIndep-tables in EP[cEP0]}
  cNrXdepTblsInEP0   = 0;   {-Nr. of Xdep-tables   in EP[cEP0]}

  {-EP[cEP0]: xIndep-Table numbering; 0&1 are reserved}
  cTb_MinMaxValKeys   = 2;
  cTb_FiltNH4_NO3     = 3;
  cTB_N_opname        = 4; {-Alleen van toepassing voor bos}
  cTB_MinROMmax       = 5; {-Alleen van toepassing voor bos}
  cTB_Kap_Graas       = 6; {-Graas alleen van toepassing voor bos}
  cTB_Vastl_N_in_LOM  = 7; {-Alleen van toepassing voor bos}
  cTB_WtrVerbr_Bomen  = 8; {-Alleen van toepassing voor bos}
  cTB_UitSpFr         = 9; {-Alleen van toepassing voor niet-bos} 

  {-Mapping of EP[cEP1]: xdep-Table numbering}
  cTb_PrecNH4       = 0;
  cTb_PrecNO3       = 1;
  cTb_Mestgift      = 2; {-Alleen van toepassing voor niet-bos}
  cTb_VegType       = 3;
  cTb_Neerslag      = 4;
  cTb_WatVerb       = 5; {-Alleen van toepassing voor niet-bos}
  cTb_Begrazen      = 6; {-Alleen van toepassing voor bos}
  cTb_Plantjaar     = 7; {-Alleen van toepassing voor bos}
  cTb_CNverhouding  = 8; {-Alleen van toepassing voor bos}
  cTB_Init_N_in_LOM = 9; {-Alleen van toepassing voor bos}

  {-VegTyp codes}
  cGrove_Corsi_Oost_Den = 1;
  cDouglas_Spar         = 2;
  cEurop_Japan_Lariks   = 3;
  cFijn_Sitkas_Spar     = 4;
  cOmonika_Overig_Spar  = 5;
  cTsugaAbiesGrandis_Chamaecyparis = 6;
  cInl_Amerik_Eik       = 7;
  cBeuk                 = 8;
  cBerk_Prunus_Loofb_Overig = 9;
  cKapvlakte            = 10;
  cLT30PrHei            = 11;
  cUpto70PrHei          = 12;
  cMT70PrHei            = 13;
  cMais                 = 14;
  cGras                 = 15;
  cLandbouwOverig       = 16;
  cBebouwing            = 17;

  {-Model specifieke fout-codes}
  cInvld_VegType        = -9100;
  cInvld_Neerslag       = -9101;
  cInvld_WatVerbNietBos = -9102;
  cInvld_Leeftijd       = -9103;
  cInvld_Init_N_in_LOM  = -9104;
  cInvld_PrecNH4        = -9105;
  cInvld_PrecNO3        = -9106;
  cInvld_CN             = -9107;
  cInvld_Mestgift       = -9108;

var
  Indx: Integer; {-Index of Boot-procedure used. Must be set by boot-procedure!}
  {-Als verschillende TBootEPArray-functies de 'mapping' beinvloeden van
    de externe parameters op de EPArray, dan kan deze variabele binnen de
    Speed-procedures worden benut om toch de gewenste gegevens te vinden}
  ModelProfile: TModelProfile;
                 {-Object met met daarin de status van de discontinuiteitsfuncties
				   (zie nDC) }

  {-Min/max values of key-values: must be set by boot-procedure!}
  cMinVegType, cMaxVegType: Integer;
  cMinNeerslag, cMaxNeerslag,
  cMinWatVerbNietBos, cMaxWatVerbNietBos,
  cMinLeeftijd, cMaxLeeftijd,
  cMin_Init_N_in_LOM, cMax_Init_N_in_LOM,
  cMinPrecNH4, cMaxPrecNH4,
  cMinPrecNO3, cMaxPrecNO3,
  cMinCN, cMaxCN,
  cMinMestgift, cMaxMestgift: Double;

  Procedure MyDllProc( Reason: Integer );
begin
  if Reason = DLL_PROCESS_DETACH then begin {-DLL is unloading}
    {-Cleanup code here}
	if ( nDC > 0 ) then
      ModelProfile.Free;
  end;
end;

Procedure DerivsProc( var x: Double; var y, dydx: TLargeRealArray;
                      var EP: TExtParArray; var Direction: TDirection;
                      var Context: Tcontext; var aModelProfile: PModelProfile; var IErr: Integer );
{-Returns the derivatives dydx at location x, given, x, the function values y
  and the external parameters EP. IErr=0 if no error occured during the
  calculation of dydx}
var
  VegType: Integer; {key-values}
  Neerslag, WatVerb, WatVerbNietBos, Leeftijd, WatVerbBos, NH4dep, NO3dep,
  Nbehoefte, NH4surplus, NO3surplus, N_min_ROM, f_LOM_NH4, f_LOM_NO3,
  NH4_N_opname_LOM, NO3_N_opname_LOM, MestGift, UitSpFr, KapNitraat,
  BegraasNitraat: Double;
  i: Integer;

Function IsBos( const VegType: Integer ): Boolean;
begin
  Result := ( VegType <= 10 )
end;

Function SetWatVerb( const VegType: Integer; var IErr: Integer ): Boolean;
begin
  IErr := cNoError; Result := true;
  if IsBos( VegType ) then begin
    WatVerb := WatVerbBos;
  end else
    WatVerb := WatVerbNietBos;
end;

Procedure Consume_N( var Nbehoefte, Surplus: Double );
begin
  if ( Nbehoefte >= Surplus ) then begin
    Nbehoefte  := Nbehoefte - Surplus;
    Surplus := 0;
  end else begin
    Surplus := Surplus - Nbehoefte;
    Nbehoefte  := 0;
  end;
end;

Function SetKeyValues( var IErr: Integer ): Boolean;
var
  PrecNH4, PrecNO3, CN, cKap, cBegraas: Double;
Function GetWatVerbBos( const VegType: Integer; const Leeftijd: Double): Double;
var
  MinLftWVma, MaxLftWVma, MaxLftWVnu, WVlftNul, WVlftMax: Double;
begin
  with EP[ cEP0 ].xInDep.Items[ cTB_WtrVerbr_Bomen ] do begin
    MinLftWVma := GetValue( 1, VegType );
    MaxLftWVma := GetValue( 2, VegType );
    MaxLftWVnu := GetValue( 3, VegType );
    WVlftNul   := GetValue( 4, VegType );
    WVlftMax   := GetValue( 5, VegType );
  end;
  if ( Leeftijd < MinLftWVma ) then
    Result := WVlftNul + Leeftijd * ( WVlftMax - WVlftNul ) / MinLftWVma
  else if ( Leeftijd < MaxLftWVma ) then
    Result := WVlftMax
  else if ( Leeftijd < MaxLftWVnu ) then
    Result := WVlftMax -
    ( Leeftijd - MaxLftWVma ) * WVlftMax / ( MaxLftWVnu - MaxLftWVma )
  else
    Result := 0;
end;
Function FiltNH4( const VegType: Integer ): Double;
begin
  with EP[ cEP0 ].xInDep.Items[ cTb_FiltNH4_NO3 ] do
    Result := GetValue( 1, VegType );
end;
Function FiltNO3( const VegType: Integer ): Double;
begin
  with EP[ cEP0 ].xInDep.Items[ cTb_FiltNH4_NO3 ] do
    Result := GetValue( 2, VegType );
end;
Function GetMaxLftOpnN( const VegType: Integer ): Double;
begin
  with EP[ cEP0 ].xInDep.Items[ cTB_N_opname ] do
    Result := GetValue( 1, VegType );
end;
Function GetNbehoefte( const VegType: Integer; const Leeftijd: Double ): Double;
var
  MaxLftOpnN, MaxOpnNb: Double;
begin
  MaxLftOpnN := GetMaxLftOpnN( VegType );
  MaxOpnNb   := EP[ cEP0 ].xInDep.Items[ cTB_N_opname ].GetValue( 2, VegType );
  if ( Leeftijd < MaxLftOpnN ) then
    Result := MaxOpnNb * ( 1 - Leeftijd / MaxLftOpnN )
  else
    Result := 0;
end;
function GetNmineralisatieROM( const VegType: Integer;
                               const Leeftijd: Double ): Double;
var
  MaxLftOpnN, MinROMmax: Double;
begin
  MaxLftOpnN := GetMaxLftOpnN( VegType );
  MinROMmax   := EP[ cEP0 ].xInDep.Items[ cTB_MinROMmax ].GetValue( 1, VegType );
  if ( Leeftijd < MaxLftOpnN ) then
    Result := MinROMmax * ( 1 - Leeftijd / MaxLftOpnN )
  else
    Result := 0;
end;

Function Get_f_LOM_NH4( const VegType: Integer; const CN: Double ): Double;
var
  CN_NH4max, CN_NH4min: Double;
begin
  with EP[ cEP0 ].xInDep.Items[ cTB_Vastl_N_in_LOM ] do begin
    CN_NH4max := GetValue( 3, VegType );
    CN_NH4min := GetValue( 4, VegType );
  end;
  if ( CN < CN_NH4min ) then
    Result := 0
  else if ( CN < CN_NH4max ) then
    Result := Min(Max( ( CN - CN_NH4min ) / ( CN_NH4max - CN_NH4min ), 0),1)
  else
    Result := 1;
end;

Function Get_f_LOM_NO3( const VegType: Integer; const CN: Double ): Double;
var
  CN_NO3max, CN_NO3min: Double;
begin
  with EP[ cEP0 ].xInDep.Items[ cTB_Vastl_N_in_LOM ] do begin
    CN_NO3max := GetValue( 1, VegType );
    CN_NO3min := GetValue( 2, VegType );
  end;
  if ( CN < CN_NO3min ) then
    Result := 0
  else if ( CN < CN_NO3max ) then
    Result := Min(Max( ( CN - CN_NO3min ) / ( CN_NO3max - CN_NO3min ), 0),1)
  else
    Result := 1;
end;

Function GetUitSpFr( const VegType: Integer ): Double;
begin
  with EP[ cEP0 ].xInDep.Items[ cTB_UitSpFr ] do
    Result := GetValue( 1, VegType );
end;

Function VegTyp( const x: Double ): Integer;
begin
  with EP[ indx-1 ].xDep do
    Result := Trunc( Items[ cTb_VegType ].EstimateY( x, Direction ) );
end;

Function Leeftd( const x: Double ): Double;
var
  Plantjaar: Double;
begin
  If IsBos( VegTyp( x ) ) then begin
    with EP[ indx-1 ].xDep do
      Plantjaar := Items[ cTb_Plantjaar ].EstimateY( x, Direction );
    Result := x - Plantjaar;
  end else
    Result := 0; {-Leeftijd van niet-bos}
end;

Function KapEffect( const x: Double ): Boolean;
var
  KapMaxTijd: Double;
  dx: Integer;
  Function GetKapMaxTijd: Double;
  begin
    with EP[ cEP0 ].xInDep.Items[ cTB_Kap_Graas ] do
      Result := GetValue( 1, 1 );
  end;
begin
  KapMaxTijd := GetKapMaxTijd;
  {$ifdef test}
  Application.MessageBox(
  PChar( 'KapMaxTijd: ' + FloatToStr( KapMaxTijd ) ), 'Info', MB_OKCANCEL );
  {$endif}

  dx         := 1;
  Result     := False;
  while ( not Result ) and ( dx <= KapMaxTijd ) do begin
    Result := ( IsBos( VegTyp( x - dx ) ) ) and {Er stond bos op jaar x-dx en..}
              ( ( Leeftd( x ) - Leeftd( x - dx ) ) < 0 ); {dat bos is gekapt}
    Inc( dx );
  end;
  if Result then
    {$ifdef test}
    Application.MessageBox( 'Wel kapeffect...', 'Info', MB_OKCANCEL )
    {$endif}
  else
  {$ifdef test}
  Application.MessageBox( 'Geen kapeffect...', 'Info', MB_OKCANCEL );
  {$endif}
end;

Function BegraasEffect( const x: Double ): Boolean;
  Function GrasMaxtijd: Double;
  begin
    with EP[ cEP0 ].xInDep.Items[ cTB_Kap_Graas ] do
      Result := GetValue( 1, 6 );
  end;
  Function Begraasd( const x: Double ): Boolean;
  begin
    Result := IsBos( VegTyp( x ) ) and
    ( EP[ indx-1 ].xDep.Items[ cTb_Begrazen ].EstimateY( x, Direction ) <> 0 );
  end;
  Function TimeElapsedSinceStart_Begrazing( const x: Double ): Double;
  begin
    Result :=
     EP[ indx-1 ].xDep.Items[ cTb_Begrazen ].DxTilNextYChange( x, BckWrd );
  end;
begin
  Result := Begraasd( x ) and {-Er wordt nu begraasd en... het is nog niet
                                zo lang geleden begonnen }
            ( TimeElapsedSinceStart_Begrazing ( x ) < GrasMaxtijd );
end;
Function KapNitFr: Double;
begin
  with EP[ cEP0 ].xInDep.Items[ cTB_Kap_Graas ] do
    Result := GetValue( 1, 2 );
end;
Function GrasNitFr: Double;
begin
  with EP[ cEP0 ].xInDep.Items[ cTB_Kap_Graas ] do
    Result := GetValue( 1, 4 );
end;

begin
  Result := False;

  {$ifdef test}
  Application.MessageBox( PChar( 'indx: ' + IntToStr( indx ) ),
  'Info', MB_OKCANCEL );
  {$endif}

  with EP[ indx-1 ].xDep do begin {-Value of indx MUST be set by boot-procedure}

    {$ifdef test}
    Application.MessageBox( PChar( 'Bepaal neerslag, cTb_Neerslag, x' +
    IntToStr( cTb_Neerslag ) + ' ' + FloatToStr( x ) ),
    'Info', MB_OKCANCEL );
    {$endif}

    Neerslag := Items[ cTb_Neerslag ].EstimateY( x, Direction );
    if ( Neerslag < cMinNeerslag ) or ( Neerslag > cMaxNeerslag ) then begin
      IErr := cInvld_Neerslag; Exit;
    end;

    {$ifdef test}
    Application.MessageBox( PChar( 'Neerslag: ' + FloatToStr( Neerslag ) ),
    'Info', MB_OKCANCEL );
    {$endif}

    VegType := VegTyp( x );
    if ( VegType < cMinVegType ) or ( VegType > cMaxVegType ) then begin
      IErr := cInvld_VegType; Exit;
    end;

    {$ifdef test}
    Application.MessageBox( PChar( 'VegType, x: ' + IntToStr( VegType ) +
                            ' ' + FloatToStr( x ) ),
    'Info', MB_OKCANCEL );
    {$endif}

    PrecNH4 := Items[ cTb_PrecNH4 ].EstimateY( x, Direction ); {-Kg N/ha/jr}
    if ( PrecNH4 < cMinPrecNH4 ) or ( PrecNH4 > cMaxPrecNH4 ) then begin
      IErr := cInvld_PrecNH4; Exit;
    end;
    NH4dep := PrecNH4 * ( 1 + FiltNH4( VegType ) ); {Stap 1}

    {$ifdef test}
    Application.MessageBox( PChar( 'NH4dep: ' + FloatToStr( NH4dep ) ),
    'Info', MB_OKCANCEL );
    {$endif}

    PrecNO3 := Items[ cTb_PrecNO3 ].EstimateY( x, Direction ); {-Kg N/ha/jr}
    if ( PrecNO3 < cMinPrecNO3 ) or ( PrecNO3 > cMaxPrecNO3 ) then begin
      IErr := cInvld_PrecNO3; Exit;
    end;
    NO3dep  := PrecNO3 * ( 1 + FiltNO3( VegType ) ); {Stap 7}

    {$ifdef test}
    Application.MessageBox( PChar( 'NO3dep: ' + FloatToStr( NO3dep ) ),
    'Info', MB_OKCANCEL );
    {$endif}

    if IsBos( VegType ) then begin
      Leeftijd := Leeftd( x );
      if ( Leeftijd < cMinLeeftijd ) or
         ( Leeftijd > cMaxLeeftijd ) then begin
        IErr := cInvld_Leeftijd; Exit;
      end;
      WatVerbBos := GetWatVerbBos( VegType, Leeftijd ); {-figuur 5}
      Nbehoefte  := GetNbehoefte( VegType, Leeftijd ); {-figuur 2}
      N_min_ROM  := GetNmineralisatieROM( VegType, Leeftijd ); {-figuur 3 boven}

      CN := Items[ cTb_CNverhouding ].EstimateY( x, Direction );
      if ( CN < cMinCN ) or ( CN > cMaxCN ) then begin
        IErr := cInvld_CN; Exit;
      end;
      f_LOM_NH4 := Get_f_LOM_NH4( VegType, CN ); {-figuur 3 onder}
      f_LOM_NO3 := Get_f_LOM_NO3( VegType, CN ); {-figuur 3 onder}

      if BegraasEffect( x ) then begin
        cBegraas := - ln( 1 - GrasNitFr );
        BegraasNitraat := y[ cOpslgN ] * cBegraas;
      end else
        BegraasNitraat := 0;

    end else begin {-IsBos = false}
      WatVerbNietBos := Items[ cTb_WatVerb ].EstimateY( x, Direction );
      {$ifdef test}
      Application.MessageBox(
       PChar( 'WatVerbNietBos: ' + FloatToStr( WatVerbNietBos ) ),
      'Info', MB_OKCANCEL );
      {$endif}

      if ( WatVerbNietBos < cMinWatVerbNietBos ) or
         ( WatVerbNietBos > cMaxWatVerbNietBos ) then begin
        IErr := cInvld_WatVerbNietBos; Exit;
      end;
      MestGift := Items[ cTb_Mestgift ].EstimateY( x, Direction );
      {$ifdef test}
      Application.MessageBox(
       PChar( 'MestGift: ' + FloatToStr( MestGift ) ), 'Info', MB_OKCANCEL );
      {$endif}

      if ( Mestgift < cMinMestgift ) or ( Mestgift > cMaxMestgift ) then begin
        IErr := cInvld_Mestgift; Exit;
      end;
      UitSpFr := GetUitSpFr( VegType );
      {$ifdef test}
      Application.MessageBox(
       PChar( 'UitSpFr: ' + FloatToStr( UitSpFr ) ), 'Info', MB_OKCANCEL );
      {$endif}
    end;


    if KapEffect( x ) then begin
     {$ifdef test}
     Application.MessageBox(
      PChar( 'KapNitFr: ' + FloatToStr( KapNitFr ) ), 'Info', MB_OKCANCEL );
     {$endif}
      cKap := - ln( 1 - KapNitFr );
      KapNitraat := y[ cOpslgN ] * cKap;
    end else
      KapNitraat := 0;

  end;
  Result := True;
end;

begin
  IErr := cUnknownError;
  for i := 1 to cNrOfDepVar do {-Default speed = 0}
    dydx[ i ] := 0;

  {-Geef de aanroepende procedure een handvat naar het ModelProfiel}
  if ( nDC > 0 ) then
    aModelProfile := @ModelProfile
  else
    aModelProfile := NIL;
  
  if ( Context = UpdateYstart ) then begin
    {-*** Override initial values on ystart-vector here}
    with EP[ indx-1 ].xDep do  {-Value of indx MUST be set by boot-procedure}
      y[ cOpslgN ] := Items[ cTB_Init_N_in_LOM ].EstimateY( 0, Direction ); {kg N/ha!}

    if ( y[ cOpslgN ] < cMin_Init_N_in_LOM ) or
       ( y[ cOpslgN ] > cMax_Init_N_in_LOM ) then begin
      IErr := cInvld_Init_N_in_LOM; Exit;
    end;
    {-*** END Override initial values on ystart-vector here}

    {-Converteer dag-waarden uit tijdreeksen en invoertijdstippen afkomstig van
      de Shell naar jaren}
    if ( indx = cBoot2 ) then
      ScaleTimesFromShell( cFromDayToYear, EP );

    IErr := cNoError;
  end else begin             {-Fill dydx-vector}
    {$ifdef test}
    Application.MessageBox( 'SetKeyValues', 'Info', MB_OKCANCEL );
    {$endif}

    if not SetKeyValues( IErr ) then
      exit;

    if SetWatVerb( VegType, IErr ) then begin
      dydx[ cNatGWaanv ] := Neerslag - WatVerb;
      {$ifdef test}
      Application.MessageBox( PChar( 'Neerslag, WatVerb: ' +
       FloatToStr( Neerslag ) + ' ' + FloatToStr( WatVerb ) ), 'Info', MB_OKCANCEL );
      {$endif}

    end else
      exit;

    if IsBos( VegType ) then begin

      {*** NH4 *********************************************************}
      NH4surplus := NH4dep; {Stap 1}
      Consume_N( Nbehoefte, NH4surplus ); {Stap 3}

      NH4surplus := NH4surplus + N_min_ROM; {Stap 2}
      Consume_N( Nbehoefte, NH4surplus ); {Stap 3}

      if ( NH4surplus > 0 ) then begin {Stap 4}
        NH4_N_opname_LOM := f_LOM_NH4 * NH4surplus; {Stap 5}
        NH4surplus       := ( 1 - f_LOM_NH4 ) * NH4surplus; {Stap 6}
      end else
        NH4_N_opname_LOM := 0;

      {*** NO3 *********************************************************}
      NO3surplus := NO3dep; {Stap 7}
      Consume_N( Nbehoefte, NO3surplus ); {Stap 8}

      if ( NO3surplus > 0 ) then begin {Stap 9}
        NO3_N_opname_LOM := f_LOM_NO3 * NO3surplus; {Stap 10}
        NO3surplus       := ( 1 - f_LOM_NO3 ) * NO3surplus; {Stap 11}
      end else
        NO3_N_opname_LOM := 0;

      dydx[ cOpslgN ] := NH4_N_opname_LOM + NO3_N_opname_LOM - BegraasNitraat;

      dydx[ cNuitsp ] := NH4surplus + NO3surplus + BegraasNitraat;

    end else begin {-Geen bos}
      dydx[ cOpslgN ] := 0;
      dydx[ cNuitsp ] := UitSpFr * ( MestGift + NH4dep + NO3dep ); 
      {$ifdef test}
      Application.MessageBox( PChar( 'UitSpFr, MestGift: ' +
       FloatToStr( UitSpFr ) + ' ' + FloatToStr( MestGift ) ), 'Info', MB_OKCANCEL );
      {$endif}

    end;

    dydx[ cOpslgN ] := dydx[ cOpslgN ] - KapNitraat;
    dydx[ cNuitsp ] := dydx[ cNuitsp ] + KapNitraat;

  end;
end; {-DerivsProc}

Function DefaultBootEP( const EpDir: String; const BootEpArrayOption: TBootEpArrayOption; var EP: TExtParArray ): Integer;
  {-xDep-tables (Gt, VegTypeuik, bodemsoort, KoeienPha, NniveauZMR,
    NniveauWNTR) are NOT set by this boot-procedure: they have to be initialised
    in another way}
Procedure SetMinMaxKeyValues;
begin
  with EP[ cEP0 ].xInDep.Items[ cTb_MinMaxValKeys ] do begin
    cMinVegType        := Trunc( GetValue( 1, 1 ) );
    cMaxVegType        := Trunc( GetValue( 1, 2 ) );
    cMinNeerslag       :=        GetValue( 1, 3 );
    cMaxNeerslag       :=        GetValue( 1, 4 );
    cMinWatVerbNietBos :=        GetValue( 1, 5 );
    cMaxWatVerbNietBos :=        GetValue( 1, 6 );
    cMinLeeftijd       :=        GetValue( 1, 7 );
    cMaxLeeftijd       :=        GetValue( 1, 8 );
    cMin_Init_N_in_LOM :=        GetValue( 2, 1 );
    cMax_Init_N_in_LOM :=        GetValue( 2, 2 );
    cMinPrecNH4        :=        GetValue( 2, 3 );
    cMaxPrecNH4        :=        GetValue( 2, 4 );
    cMinPrecNO3        :=        GetValue( 2, 5 );
    cMaxPrecNO3        :=        GetValue( 2, 6 );
    cMinCN             :=        GetValue( 2, 7 );
    cMaxCN             :=        GetValue( 2, 8 );
    cMinMestgift       :=        GetValue( 3, 1 );
    cMaxMestgift       :=        GetValue( 3, 2 );
  end;
end;
Begin
  Result := DefaultBootEPFromTextFile( EpDir, BootEpArrayOption, cModelID, cNrOfDepVar, nDC,
            cNrXIndepTblsInEP0, cNrXdepTblsInEP0, Indx, EP );
  if ( Result = cNoError ) then
    SetMinMaxKeyValues;
end;

Function TestBootEP( const EpDir: String; const BootEpArrayOption: TBootEpArrayOption; var EP: TExtParArray ): Integer;
  {-Apart from the defaults for TestBootEP, this procedure also sets the
    xDep-tables, so the model is ready-to-run }
Begin
  Result := DefaultBootEP( EpDir, BootEpArrayOption, EP );
  if ( Result <> cNoError ) then exit;
  Result := DefaultTestBootEPFromTextFile( EpDir, BootEpArrayOption, cModelID, cnRP + cnSQ + cnRQ, Indx,
                                           EP );
  if ( Result <> cNoError ) then exit;
  SetReadyToRun( EP);
  {$ifdef test}
  Application.MessageBox( 'ReadyToRun', 'Info', MB_OKCANCEL );
  {$endif}

end;

Function BootEPForShell( const EpDir: String; const BootEpArrayOption: TBootEpArrayOption; var EP: TExtParArray ): Integer;
  {-xDep-tables are NOT set by this boot-procedure: they must be supplied
    by the shell }
begin
  Result := DefaultBootEP( EpDir, cBootEPFromTextFile, EP );
  if ( Result = cNoError ) then
    Result := DefaultBootEPForShell( cnRP, cnSQ, cnRQ, Indx, EP );
end;

Exports DerivsProc       index cModelIndxForTDSmodels, {999}
        DefaultBootEP    index cBoot0, {1}
        TestBootEP       index cBoot1, {2}
        BootEPForShell   index cBoot2; {3}
begin
  {-This 'DLL-Main-block' is executed  when the DLL is initially loaded into
    memory (Reason = DLL_PROCESS_ATTACH)}
  DLLProc := @MyDllProc;
  Indx := cBootEPArrayVariantIndexUnknown;
  if ( nDC > 0 ) then
    ModelProfile := TModelProfile.Create( nDC );
end.
