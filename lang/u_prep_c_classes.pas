unit u_prep_c_classes;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, u_globalvars, u_variables, u_prep_global,
  u_prep_expressions,
  u_prep_codeblock, u_classes, u_prep_methods, u_prep_c_global,
  u_prep_c_methods;

function IsClassDefine(s: string): boolean;
function PreprocessClassDefine(s: string): string;
function IsInClassBlock: boolean;
//procedure PreprocessClassVarDefine(s: string; varmgr: TVarManager; MClass: TMashClass);
procedure PreprocessClassVarDefines(s: string; varmgr: TVarManager; MClass: TMashClass);
function PreprocessClassPart(s: string; varmgr: TVarManager): string;
function GenClassAllocator(MClass: TMashClass; varmgr: TVarManager): string;

implementation

function IsClassDefine(s: string): boolean;
begin // class ClassName:
  Result := False;
  s := Trim(s);
  if copy(s, 1, 6) = 'class ' then
  begin
    Delete(s, 1, 6);
    s := Trim(s);
    if Length(s) > 1 then
      Result := s[length(s)] = ':';
  end;
end;

function PreprocessClassDefine(s: string): string;
var
  Mc, Mc2: TMashClass;
  Bf: string;
  c: cardinal;
begin
  Result := '';
  s := Trim(s);
  Delete(s, 1, 5);
  Delete(s, Length(s), 1);
  s := Trim(s);
  bf := GetProcName(s);

  if (Pos('(', s) > 0) and (s[length(s)] = ')') then
  begin
    Mc := TMashClass.Create(bf);
    Delete(s, length(s), 1);
    Delete(s, 1, pos('(', s));

    while Length(s) > 0 do
    begin
      bf := Trim(CutNextArg(s));
      Mc.Extends.Add(bf);
      Mc2 := FindClassRec(bf);

      if Mc2 <> nil then
      begin
        c := 0;
        while c < Mc2.Methods.Count do
        begin
          if Mc.Methods.IndexOf(Mc2.Methods[c]) = -1 then
          begin
            Mc.Methods.Add(Mc2.Methods[c]);
            Mc.MethodsLinks.Add(Mc2.MethodsLinks[c]);
          end
          else
            Mc.MethodsLinks[c] := Mc2.MethodsLinks[c];
          Inc(c);
        end;
      end
      else
       Mc.UnresolvedDepends.Add(bf);

    end;
  end
  else
    Mc := TMashClass.Create(s);

  BlockStack.Add(TCodeBlock.Create(btClass, bf, '', ''));
  ClassStack.Add(Mc);
end;

function IsInClassBlock: boolean;
begin
  Result := False;
  if BlockStack.Count > 0 then
    Result := TCodeBlock(BlockStack[BlockStack.Count - 1]).bType = btClass;
end;

(*procedure PreprocessClassVarDefine(s: string; varmgr: TVarManager; MClass: TMashClass);
var
  v, def: string;
  vr: TMashClassVariableDefine;
begin
  Def := '';
  s := Trim(s);
  if s[1] = '$' then
    Delete(s, 1, 1);
  if s = '' then
    PrpError('empty class variable definition.');
  if pos('=', s) > 0 then
  begin
    v := Trim(copy(s, 1, pos('=', s) - 1));
    Delete(s, 1, pos('=', s));
    s := Trim(s);
    if IsOpNew(s) then
      Def := PreprocessOpNew(s, varmgr)
    else
    //Result := Result + sLineBreak + PushIt(s, varmgr);
    if IsVar(s, varmgr) then
      Def := PreprocessVarAction(s, 'push', varmgr)
    else
    if IsConst(s) then
      Def := 'pushc ' + GetConst(s)
    else
    if IsArr(s) then
      Def := PreprocessArrAction(s, 'pushai', varmgr)
    else
    if IsExpr(s) then
      Def := PreprocessExpression(s, varmgr)
    else
    if (Pos('(', s) > 0) and (s[1] <> '[') then
    begin
      if (ProcList.IndexOf(TryToGetProcName(s)) <> -1) or
        (ImportsLst.IndexOf(TryToGetProcName(s)) <> -1) then
      begin
        if pos('(', s) > 0 then
        begin
          Def := PreprocessCall(s, varmgr);
          s := GetProcName(Trim(s));
        end;

        s := Trim(s);

        Def := Def + sLineBreak + 'pushc ' + GetConst('!' + s) +
          sLineBreak + 'gpm' + sLineBreak;
        if ProcList.IndexOf(s) <> -1 then
          Def := Def + 'jc'
        else
          Def := Def + 'invoke';
      end
      else
        PrpError('Invalid calling "' + s + '".');
    end
    else
      Def := Def + sLineBreak + PushIt(s, varmgr);
    vr := TMashClassVariableDefine.Create(v, True, Def);
    MClass.VarDefs.Add(vr);
  end
  else
  begin
    vr := TMashClassVariableDefine.Create(v, False, '');
    MClass.VarDefs.Add(vr);
  end;
end;*)

procedure PreprocessClassVarDefines(s: string; varmgr: TVarManager; MClass: TMashClass);
begin
  while Length(s) > 0 do
  begin
    MClass.VarDefs.Add(TMashClassVariableDefine.Create(Trim(CutNextArg(s)), False, ''));
    //PreprocessClassVarDefine(CutNextArg(s), varmgr, MClass);
  end;
end;


function PreprocessClassPart(s: string; varmgr: TVarManager): string;
var
  mc: TMashClass;
  bf: string;
  i: integer;
begin
  Result := '';
  s := Trim(s);
  {if IsProc(s) then
  begin
    Mc := TMashClass(ClassStack[ClassStack.Count - 1]);
    Bf := s;
    Delete(Bf, 1, 4);
    Bf := Trim(Bf);
    if copy(Bf, 1, 1) = '!' then
    begin
      Delete(Bf, 1, 1);
      Delete(s, pos('!', s), 1);
      Bf := GetProcName(Bf);
      Result := PreprocessProc(s, varmgr, True, Mc.CName);

      Mc.Methods.Add(bf);
      Mc.MethodsLinks.Add(Mc.CName + '__' + bf);

      Bf := Mc.CName + '__' + bf;

      if ProcList.IndexOf(Bf) = -1 then
        ProcList.Add(Bf);
      if ConstDefs.IndexOf(Bf) = -1 then
        ConstDefs.Add(Bf);

    end
    else
     PrpError('Globally method declaration in class "' + Mc.CName + '" declaration!');
  end
  else}
  if s = 'end' then
    GenEnd
  else
  if copy(s, 1, 4) = 'var ' then
  begin
    Delete(s, 1, 3);
    s := Trim(s);
    PreprocessClassVarDefines(s, varmgr, TMashClass(ClassStack[ClassStack.Count - 1]));
  end
  else
  if (copy(s, 1, 5) = 'func ') or (copy(s, 1, 5) = 'proc ') then
  begin
    Delete(s, 1, 4);
    s := Trim(s);
    while Length(s) > 0 do
    begin
      Mc := TMashClass(ClassStack[ClassStack.Count - 1]);
      bf := Trim(CutNextArg(s));

      {if copy(bf, 1, 2) = '++' then
       begin
         Delete(bf, 1, 2);
         mc.OperatorsDefs.Add(TMashClassOperatorDefine.Create(bf, svmopidInc));
       end
      else
      if copy(bf, 1, 2) = '--' then
       begin
         Delete(bf, 1, 2);
         mc.OperatorsDefs.Add(TMashClassOperatorDefine.Create(bf, svmopidDec));
       end
      else
      if copy(bf, 1, 2) = '<<' then
       begin
         Delete(bf, 1, 2);
         mc.OperatorsDefs.Add(TMashClassOperatorDefine.Create(bf, svmopidShl));
       end
      else
      if copy(bf, 1, 2) = '>>' then
       begin
         Delete(bf, 1, 2);
         mc.OperatorsDefs.Add(TMashClassOperatorDefine.Create(bf, svmopidShr));
       end
      else
      if copy(bf, 1, 2) = '==' then
       begin
         Delete(bf, 1, 2);
         mc.OperatorsDefs.Add(TMashClassOperatorDefine.Create(bf, svmopidEq));
       end
      else
      if copy(bf, 1, 2) = '>=' then
       begin
         Delete(bf, 1, 2);
         mc.OperatorsDefs.Add(TMashClassOperatorDefine.Create(bf, svmopidBe));
       end
      else
      if copy(bf, 1, 1) = '+' then
       begin
         Delete(bf, 1, 1);
         mc.OperatorsDefs.Add(TMashClassOperatorDefine.Create(bf, svmopidAdd));
       end
      else
      if copy(bf, 1, 1) = '-' then
       begin
         Delete(bf, 1, 1);
         mc.OperatorsDefs.Add(TMashClassOperatorDefine.Create(bf, svmopidSub));
       end
      else
      if copy(bf, 1, 1) = '*' then
       begin
         Delete(bf, 1, 1);
         mc.OperatorsDefs.Add(TMashClassOperatorDefine.Create(bf, svmopidMul));
       end
      else
      if copy(bf, 1, 1) = '/' then
       begin
         Delete(bf, 1, 1);
         mc.OperatorsDefs.Add(TMashClassOperatorDefine.Create(bf, svmopidDiv));
       end
      else
      if copy(bf, 1, 1) = '\' then
       begin
         Delete(bf, 1, 1);
         mc.OperatorsDefs.Add(TMashClassOperatorDefine.Create(bf, svmopidIDiv));
       end
      else
      if copy(bf, 1, 1) = '%' then
       begin
         Delete(bf, 1, 1);
         mc.OperatorsDefs.Add(TMashClassOperatorDefine.Create(bf, svmopidMod));
       end
      else
      if copy(bf, 1, 1) = '>' then
       begin
         Delete(bf, 1, 1);
         mc.OperatorsDefs.Add(TMashClassOperatorDefine.Create(bf, svmopidBg));
       end
      else
      if copy(bf, 1, 1) = '&' then
       begin
         Delete(bf, 1, 1);
         mc.OperatorsDefs.Add(TMashClassOperatorDefine.Create(bf, svmopidAnd));
       end
      else
      if copy(bf, 1, 1) = '|' then
       begin
         Delete(bf, 1, 1);
         mc.OperatorsDefs.Add(TMashClassOperatorDefine.Create(bf, svmopidOr));
       end
      else
      if copy(bf, 1, 1) = '^' then
       begin
         Delete(bf, 1, 1);
         mc.OperatorsDefs.Add(TMashClassOperatorDefine.Create(bf, svmopidXor));
       end
      else
      if copy(bf, 1, 1) = '~' then
       begin
         Delete(bf, 1, 1);
         mc.OperatorsDefs.Add(TMashClassOperatorDefine.Create(bf, svmopidNot));
       end
      else
      if copy(bf, 1, 1) = '=' then
       begin
         Delete(bf, 1, 1);
         mc.OperatorsDefs.Add(TMashClassOperatorDefine.Create(bf, svmopidMov));
       end;}

      i := Mc.Methods.IndexOf(bf);
      if i = -1 then
      begin
        Mc.Methods.Add(bf);
        Mc.MethodsLinks.Add(Mc.CName + '__' + bf);
      end
      else
        Mc.MethodsLinks[i] := Mc.CName + '__' + bf;
    end;
  end
  else
  if (s = 'public:') or (s = 'protected:') or (s = 'private:') or
    (s = 'public :') or (s = 'protected :') or (s = 'private :') then
  //It's formality
  else
  if s <> '' then
    PrpError('Invalid class definition, class: <' +
      TMashClass(ClassStack[ClassStack.Count - 1]).CName + '>.');
end;

function GenClassAllocator(MClass: TMashClass; varmgr: TVarManager): string;
var
  mname: string;
  c: cardinal;
begin
  // Allocation

  mname := '__class_' + MClass.CName + '_allocator';
  Result := mname + ':' + sLineBreak + PushIt(IntToStr(MClass.AllocSize),
    varmgr, True, True) + sLineBreak + PushIt('1', varmgr, True, True) +
    sLineBreak + 'newa' + sLineBreak + 'typemarkclass' + sLineBreak;

  // Introspection
  if RTTI_Enable then
    Result := Result + 'pcopy' + sLineBreak + 'pushcp ' + MClass.CName +
      sLineBreak + 'swp' + sLineBreak + 'pushcp ' + ClassChildPref +
      'type' + sLineBreak + 'swp' + sLineBreak + 'peekai' + sLineBreak;

  // StructFree()
  {Result := Result + 'pcopy' + sLineBreak + 'pushcp ' + '__class_' +
    MClass.CName + '_rem' + sLineBreak + 'swp' + sLineBreak +
    'pushcp ' + ClassChildPref + 'rem' + sLineBreak + 'swp' +
    sLineBreak + 'peekai' + sLineBreak;}

  c := 0;
  while c < MClass.Methods.Count do
  begin
    Result := Result + 'pcopy' + sLineBreak + 'pushcp ' + MClass.MethodsLinks[c] +
      sLineBreak + 'swp' + sLineBreak + 'pushcp ' + ClassChildPref +
      MClass.Methods[c] + sLineBreak + 'swp' + sLineBreak + 'peekai' + sLineBreak;
    Inc(c);
  end;

  // Operator's definitions
  {c := 0;
  while c < MClass.OperatorsDefs.Count do
   begin
     Result := Result + sLineBreak + 'pcopy' +
               sLineBreak + 'pushcp __class__child_' +
               TMashClassOperatorDefine(MClass.OperatorsDefs[c]).HandlerName +
               sLineBreak + 'swp' + sLineBreak + 'pushcp ' +
               GetConst(IntToStr(byte(TMashClassOperatorDefine(MClass.OperatorsDefs[c]).OpType)),varmgr) +
               sLineBreak + 'swp' + sLineBreak + 'copst' + sLineBreak;
     Inc(c);
   end;}

  Result := Result + '__gen_' + mname + '_method_end:' + sLineBreak + 'jr' + sLineBreak;

  // Clear memory

  {mname := '__class_' + MClass.CName + '_rem';
  Result := Result + sLineBreak + mname + ':';

  // Introspection
  if RTTI_Enable then
   Result := Result + sLineBreak + 'pcopy' + sLineBreak + 'pushcp ' + ClassChildPref + 'type' + sLineBreak +
             'swp' + sLineBreak + 'pushai' + sLineBreak + 'rem';

  Result := Result + sLineBreak + 'pcopy' + sLineBreak + 'pushcp ' +
    ClassChildPref + 'rem' + sLineBreak +
    'swp' + sLineBreak + 'pushai' + sLineBreak + 'rem';

  c := 0;
  while c < MClass.Methods.Count do
  begin
    Result := Result + sLineBreak + 'pcopy' + sLineBreak + 'pushcp ' +
      ClassChildPref + MClass.Methods[c] + sLineBreak + 'swp' +
      sLineBreak + 'pushai' + sLineBreak + 'rem';
    Inc(c);
  end;

  Result := Result + sLineBreak + 'rem' + //sLineBreak + 'pop' +
    sLineBreak + '__gen_' + mname + '_method_end:' + sLineBreak + 'jr' + sLineBreak;}
end;

end.
