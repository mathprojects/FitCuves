unit uMain;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.Controls.Presentation, FMX.StdCtrls, System.Generics.Collections,
  System.Math, FMX.Memo.Types, FMX.ScrollBox, FMX.Memo, fitCurves;

type
  TFitCurvesDemoForm = class(TForm)
    Button1: TButton;
    Memo1: TMemo;
    procedure Button1Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  FitCurvesDemoForm: TFitCurvesDemoForm;

implementation

{$R *.fmx}


procedure TFitCurvesDemoForm.Button1Click(Sender: TObject);
var
  points: TPoints;

  beziers: TBeziers;
  i: Integer;
begin
  points := TPoints.Create;

  points.add(TPointF.Create(5,5));
  points.add(TPointF.Create(8,10));
  points.add(TPointF.Create(10, 1));
  points.add(TPointF.Create(12,5));
  points.add(TPointF.Create(15,7));
  points.add(TPointF.Create(20,12));

  beziers := FitCurve(points, 10);

  for i := 0 to beziers.count-1 do
  begin
    memo1.lines.add('P1=' + FloatToStr(beziers[i][0].X) + ',' + FloatToStr(beziers[i][0].Y));
    memo1.lines.add('C1=' + FloatToStr(beziers[i][1].X) + ',' + FloatToStr(beziers[i][1].Y));
    memo1.lines.add('C2=' + FloatToStr(beziers[i][2].X) + ',' + FloatToStr(beziers[i][2].Y));
    memo1.lines.add('P2=' + FloatToStr(beziers[i][3].X) + ',' + FloatToStr(beziers[i][3].Y));
    memo1.lines.Add('------');
  end;

end;

end.
