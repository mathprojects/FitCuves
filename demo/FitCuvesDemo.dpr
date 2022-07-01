program FitCuvesDemo;

uses
  System.StartUpCopy,
  FMX.Forms,
  uMain in 'uMain.pas' {FitCurvesDemoForm};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TFitCurvesDemoForm, FitCurvesDemoForm);
  Application.Run;
end.
