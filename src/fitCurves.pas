(*
    Delphi/Object Pascal implementation of
      Algorithm for Automatically Fitting Digitized Curves
      by Philip J. Schneider
      "Graphics Gems", Academic Press, 1990

    Given a set of points and a max allowed error, one or more Bezier curves
    are fitted to the points.

    The C code from the above mentioned citation can be found at
    https://github.com/erich666/GraphicsGems .

    Also, a Python implement, which was extremely helpful in porting fitCurves
    to Delphi/Object Pascal, can be found at
    https://github.com/volkerp/fitCurves .

*)
unit fitCurves;

interface

uses
  System.Types, System.SysUtils, System.Math, System.Generics.Collections;

type
  TBezier = array[0..3] of TPointF;
  TBeziers = TList<TBezier>;
  TPoints = TList<TPointF>;
  TParameters = TList<single>;

  function FitCurve(points: TPoints; maxError: single): TBeziers;

implementation

function CreateBezier(P1, C1, C2, P2: TPointF): TBezier;
begin
  result[0] := P1;
  result[1] := C1;
  result[2] := C2;
  result[3] := P2;
end;

function ChordLengthParameterize(points: TPoints): TParameters;
var
  i: Integer;
begin
  result := TParameters.Create;
  result.Add(0.0);

  for i := 1 to points.Count - 1 do
     result.Add(result[i-1] + (points[i] - points[i-1]).Length);

  for i := 0 to result.Count -1 do
    result[i] := result[i] / result.Last;
end;

(* evaluates cubic bezier at t, return point *)
function Bezier_q(ctrlPoly: TBezier; t: real): TPointF;
begin
  result := Power(1.0 - t, 3) * ctrlPoly[0] + 3 * Power(1.0 - t, 2) * t
            * ctrlPoly[1] + 3 * (1.0 - t) * Power(t, 2)
            * ctrlPoly[2] + Power(t, 3)
            * ctrlPoly[3];
end;

function GenerateBezier(points: TPoints; parameters: TParameters; leftTangent: TPointF; rightTangent: TPointF): TBezier;
var
  i: integer;
  A: array of array[0..1] of TPointF;
  C: array[0..1] of array[0..1] of real;
  X: array[0..1] of real;
  tmp: TPointF;
  det_C0_C1,
  det_C0_X,
  det_X_C1: real;
  alpha_l,
  alpha_r: real;
  segLength: real;
  epsilon: real;
begin
  result[0] := points.First;
  result[3] := points.Last;

  (* compute the A's *)
  setlength(A, points.count);
  for i := 0 to high(A) do
  begin
    A[i][0] := leftTangent * 3 * Power(1 - parameters[i], 2) * parameters[i];
    A[i][1] := rightTangent * 3 * (1 - parameters[i]) * Power(parameters[i], 2);
  end;

  (* Create the C and X matrices *)
  for i := 0 to points.count-1 do
  begin
    C[0][0] := A[i][0].DotProduct(A[i][0]);
    C[0][1] := A[i][0].DotProduct(A[i][1]);
    C[1][0] := A[i][0].DotProduct(A[i][1]);
    C[0][1] := A[i][1].DotProduct(A[i][1]);

    tmp := points[i] - Bezier_q(CreateBezier(points.First, points.First, points.Last, points.Last), parameters[i]);

    X[0] := A[i][0].DotProduct(tmp);
    X[1] := A[i][1].DotProduct(tmp);
  end;

  (* Compute the determinants of C and X *)
  det_C0_C1 := C[0][0] * C[1][1] - C[1][0] * C[0][1];
  det_C0_X  := C[0][0] * X[1] - C[1][0] * X[0];
  det_X_C1  := X[0] * C[1][1] - X[1] * C[0][1];

  (* Finally, derive alpha values *)
  if det_C0_C1 = 0 then
    alpha_l := 0.0
  else
    alpha_l := det_X_C1 / det_C0_C1;

  if det_C0_C1 = 0 then
    alpha_r := 0.0
  else
    alpha_r := det_C0_X / det_C0_C1;

  (* If alpha negative, use the Wu/Barsky heuristic (see text)
     (if alpha is 0, you get coincident control points that lead to
     divide by zero in any subsequent NewtonRaphsonRootFind() call.
  *)
  segLength := (points.First - points.Last).Length;
  epsilon := 1.0E-6 * segLength;
  if (alpha_l < epsilon) or (alpha_r < epsilon) then
  begin
    (* fall back on standard (probably inaccurate) formula, and subdivide further if needed. *)
    result[1] := result[0] + leftTangent * (segLength / 3.0);
    result[2] := result[3] + rightTangent * (segLength / 3.0);
  end
  else
  begin
    (* First and last control points of the Bezier curve are
       positioned exactly at the first and last data points
       Control points 1 and 2 are positioned an alpha distance out
       on the tangent vectors, left and right, respectively
    *)
    result[1] := result[0] + leftTangent * alpha_l;
    result[2] := result[3] + rightTangent * alpha_r;
  end;

end;

procedure ComputeMaxError(points: TPoints; bez: TBezier; parameters: TParameters; var maxError: real; var splitPoint: integer);
var
  i: Integer;
  dist: real;
begin
  maxError := 0.0;
  splitPoint := trunc(points.Count / 2);
  for i := 0 to points.Count - 1 do
  begin
    dist := Power((Bezier_q(bez, parameters[i]) - points[i]).Length, 2);
    if dist > maxError then
    begin
      maxError := dist;
      splitPoint := i;
    end;
  end;
end;

(* evaluates cubic bezier first derivative at t, return point *)
function Bezier_qprime(ctrlPoly: TBezier; t: real): TPointF;
begin
  result := 3 * Power(1.0 - t, 2) * (ctrlPoly[1] - ctrlPoly[0])
            + 6 * (1.0 - t) * (ctrlPoly[2] - ctrlPoly[1])
            + 3 * Power(t, 2) * (ctrlPoly[3] - ctrlPoly[2]);
end;

(* evaluates cubic bezier second derivative at t, return point *)
function Bezier_qprimeprime(ctrlPoly: TBezier; t: real): TPointF;
begin
  result := 6 * (1.0 - t) * (ctrlPoly[2] - 2 * ctrlPoly[1] - ctrlPoly[0])
            + 6 * t * (ctrlPoly[3] - 2 * ctrlPoly[2] + ctrlPoly[1]);
end;

function NewtonRaphsonRootFind(bez: TBezier; point: TPointF; u: real): real;
var
  d: TPointF;
  numerator,
  denominator: real;
  qp: TPointF;
  qpp: TPointF;
begin
  (*
       Newton's root finding algorithm calculates f(x)=0 by reiterating
       x_n+1 = x_n - f(x_n)/f'(x_n)

       We are trying to find curve parameter u for some point p that minimizes
       the distance from that point to the curve. Distance point to curve is d=q(u)-p.
       At minimum distance the point is perpendicular to the curve.
       We are solving
       f = q(u)-p * q'(u) = 0
       with
       f' = q'(u) * q'(u) + q(u)-p * q''(u)

       gives
       u_n+1 = u_n - |q(u_n)-p * q'(u_n)| / |q'(u_n)**2 + q(u_n)-p * q''(u_n)|
  *)

  d := Bezier_q(bez, u) - point;
  qp := Bezier_qprime(bez, u);
  qpp := Bezier_qprimeprime(bez, u);
  numerator := d.X * qp.X + d.Y * qp.Y;

  qp.X := qp.X * qp.X;
  qp.Y := qp.Y * qp.Y;
  qpp.X := d.X * qpp.X;
  qpp.Y := d.Y * qpp.Y;
  denominator := qp.X + qpp.X + qp.Y + qpp.Y;

  if denominator = 0.0 then
      result := u
  else
      result := u - numerator/denominator;
end;

function reparameterize(bezier: TBezier; points: TPoints; parameters: TParameters): TParameters;
var
  i: integer;
begin
  result := TParameters.Create;

  for i  := 0 to points.Count - 1 do
    result.Add(newtonRaphsonRootFind(bezier, points[i], parameters[i]));
end;

function Normalize(v: TPointF): TPointF;
begin
  result := v / v.Length;
end;

function FitCubic(points: TPoints; leftTangent: TPointF; rightTangent: TPointF; error: single): TBeziers;
var
  dist: single;
  bezCurve: TBezier;
  u: TParameters;
  maxError: real;
  splitPoint: integer;
  i: Integer;
  uPrime: TParameters;
  splitPoints: TPoints;
  centerTangent: TPointF;
  tmpBeziers: TBeziers;
begin
  result := TBeziers.Create;

  (* Use heuristic if region only has two points in it *)

  if points.Count = 2 then
  begin
    dist := (Points[0] - Points[1]).Length;
    bezCurve[0] := points[0];
    bezCurve[1] := points[0] + leftTangent * dist;
    bezCurve[2] := points[1] + rightTangent * dist;
    bezCurve[3] := points[1];
    result.Add(bezCurve);
    exit;
  end;

  (* Parameterize points, and attempt to fit curve *)
  u := chordLengthParameterize(points);
  bezCurve := GenerateBezier(points, u, leftTangent, rightTangent);

  (* Find max deviation of points to fitted curve *)
  ComputeMaxError(points, bezCurve, u, maxError, splitPoint);
  if maxError < error then
  begin
    result.Add(bezCurve);
    exit;
  end;

  (* If error not too large, try some reparameterization and iteration *)
  if maxError < Power(error, 2) then
    for i := 0 to 19 do
    begin
      uPrime := reparameterize(bezCurve, points, u);
      bezCurve := generateBezier(points, uPrime, leftTangent, rightTangent);
      ComputeMaxError(points, bezCurve, uPrime, maxError, splitPoint);
      if maxError < error then
      begin
        result.Add(bezCurve);
        uPrime.Free;
        exit;
      end;
      u.Clear;
      u.AddRange(uPrime);
      uPrime.Free;
    end;

  u.Free;

  (* Fitting failed -- split at max error point and fit recursively *)
  result.Clear;
  centerTangent := normalize(points[splitPoint-1] - points[splitPoint+1]);
  splitPoints := TPoints.Create;
  for i := 0 to splitPoint do
    splitPoints.Add(points[i]);
  tmpBeziers := FitCubic(splitPoints, leftTangent, centerTangent, error);
  result.AddRange(tmpBeziers);
  FreeAndNil(tmpBeziers);
  splitPoints.Clear;
  for i := splitPoint to points.Count - 1 do
    splitPoints.Add(points[i]);
  tmpBeziers := FitCubic(splitPoints, -centerTangent, rightTangent, error);
  result.AddRange(tmpBeziers);
  splitPoints.Free;
  tmpBeziers.Free;
end;

(* Fit one (ore more) Bezier curves to a set of points *)
function FitCurve(points: TPoints; maxError: single): TBeziers;
var
  leftTangent: TPointF;
  rightTangent: TPointF;
begin
  leftTangent := (points[1] - points[0]).Normalize;
  rightTangent := (points[points.Count-1] - points[points.Count-2]).Normalize;
  result := FitCubic(points, leftTangent, rightTangent, maxError);
end;

end.
