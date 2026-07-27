(*
 * SpxDedupe -- how near two variants are, and generating N that are not (spec §4.6).
 *
 * Pure and GUI-free, like the rest of editor-core: the whole batch loop is gated by the
 * console suite, and the export tab is wiring over it.
 *
 * WHY SHINGLES AND NOT EQUALITY. A spun set whose texts merely DIFFER is worthless -- two
 * variants that share every sentence but one word are the same article to a reader and to a
 * search engine, and exact comparison calls them unique. So variants are compared as sets of
 * overlapping word runs (shingles), and a pair whose overlap reaches the threshold is one
 * text, not two. That is the measure spintax.ru exposes, and the size and the threshold stay
 * the author's to set, because "too similar" depends on the job.
 *
 * WHY A RETRY BUDGET. Dropping a duplicate leaves the set short of N, so the loop takes the
 * next seed and tries again -- but a thin template can be asked for a hundred variants when
 * it can only produce nine, and the loop must end. The budget bounds the extra seeds; the
 * report says requested / generated / dropped, which is exactly where thin variability
 * becomes visible to the author rather than becoming a silent short set.
 *
 * SEEDS STAY MEANINGFUL. Every variant keeps the seed that produced it, replacements
 * included, so the set is still reproducible one variant at a time -- and the report carries
 * the seed the next batch should start from, so "give me twenty more" does not re-tread the
 * same ground.
 *)
unit SpxDedupe;

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, Spintax, SpxStudio;

type
  { A text's fingerprint: the hashes of its shingles, sorted and unique. An array rather than
    a set or a dictionary because the only operation on it is a merge with another one. }
  TSpxHashes = array of LongWord;

  { What counts as "the same text". }
  TSpxDedupeOpts = record
    { Words per shingle. Small k finds paraphrase, large k only near-copies; 4 is the usual
      starting point and what spintax.ru defaults to. Clamped to >= 1. }
    ShingleSize: Integer;
    { Overlap at or above which a variant is a duplicate, 0..1 as a Jaccard ratio. 1.0 means
      "only if the shingle sets are identical", which is the closest this gets to exact
      comparison; 0 would call everything a duplicate and is clamped away from that.

      The scale is LENGTH-RELATIVE, which is worth knowing before turning the knob: one word
      changed in a nine-word sentence moves four of its six shingles and scores 0.20, the
      same edit in a hundred-word paragraph moves four of a hundred and ten and scores 0.93.
      That is the intended behaviour -- proportion is what a reader notices too.

      It is also REPETITION-sensitive, which is less obvious: shingles are deduplicated, so a
      text that reuses its phrasing has a smaller fingerprint and scores higher against its
      own siblings. Two templates with a comparable amount of real choice can land far apart
      because one repeats itself more. }
    Threshold: Double;
    { Extra seeds the loop may spend replacing duplicates, on top of the N it was asked for.
      So the loop renders at most N + RetryBudget times, and zero means no retries at all:
      whatever survives the first N seeds is the set. }
    RetryBudget: Integer;
  end;

  { What the batch actually did. Requested is what was asked for, Generated what came back,
    Dropped how many were thrown away as duplicates -- and Exhausted says which of the two
    ends stopped the loop, because "N unique found" and "ran out of budget" look identical
    from the outside and mean opposite things about the template. }
  TSpxBatchReport = record
    Requested: Integer;
    Generated: Integer;
    Dropped: Integer;
    { Seeds actually spent, i.e. renders performed. Carried as a plain Integer on purpose:
      NextSeed - SeedBase would give the same number only until the range wraps, and then it
      raises in a checked build -- which is exactly what a caller would write. }
    Tried: Integer;
    SeedBase: LongWord;
    { The seed the NEXT batch should start from -- one past the last one tried, so a second
      run continues instead of repeating. Wraps with the range. }
    NextSeed: LongWord;
    Exhausted: Boolean;
  end;

{ 4-word shingles, 0.75, and a budget of twice the request.

  The threshold is measured, not borrowed. Pairwise similarity over a plain batch of 20:
  the demo template spreads 0.23-0.56 (mean 0.34), a real 18 KB article template 0.09-0.39
  (mean 0.20) -- while a long text whose only alternation is ONE word runs 0.79-1.00 (mean
  0.90). Those three leave a band between about 0.56 and 0.79 with nothing in it, and 0.75
  sits inside it, deliberately near the top: 0.19 of margin on the varied side against 0.04
  on the near-copy side, because keeping a near-duplicate is the failure that matters and
  dropping a good variant only costs a retry. 0.8, the number spintax.ru shows, is just
  OUTSIDE the band -- it would have kept the 0.79 pairs, which are the exact thing this is
  for.

  Three templates are not a corpus, and the band is not a property of the measure: a template
  that repeats its phrasing scores higher against itself whatever its real variety (see
  Threshold). Where "too similar" falls is an editorial call in the end, which is why the
  knob is the author's. }
function SpxDefaultDedupeOpts: TSpxDedupeOpts;

{ The shingle fingerprint of a text: hashes of every k-word run, deduplicated and sorted.
  Sorted because that is what makes the comparison a linear merge rather than a nested scan,
  and hashed because the texts are HTML -- keeping the words themselves would cost more
  memory than the whole batch.

  Words are runs of non-space bytes, case-folded through the ENGINE'S OWN table
  (SpUpperCodePoint), not through an ASCII fold. The first version folded A-Z only, on the
  reasoning that renders of one template repeat the same words in the same case. That
  reasoning is wrong for this app and the error runs the dangerous way: Studio always renders
  with PostProcess on, and the engine's capitalisation pass re-cases the word after `.`, `!`,
  `?` and after block tags -- so an alternation that moves a sentence boundary changes the
  case of the NEXT word. Measured on a Cyrillic render pair, the ASCII fold reported 0.46
  where the same construction in Latin reported 0.64, and a text differing ONLY in case
  scored 0.00 instead of 1.00. Understated similarity means near-duplicates survive, which is
  precisely what this unit exists to prevent.

  Text shorter than k words yields one shingle, so short variants still compare instead of
  silently matching everything. }
function SpxShingles(const Text: string; Size: Integer): TSpxHashes;

{ Jaccard overlap of two fingerprints: |A and B| / |A or B|, 0..1. Two empty texts are
  identical (1.0); one empty against a non-empty one shares nothing (0.0). }
function SpxSimilarity(const A, B: TSpxHashes): Double;

{ N variants no two of which are within the threshold of each other.

  Seeds run SeedBase, SeedBase+1, ... exactly as SpxRenderBatch derives them, so a set built
  here is the same set that a plain batch would have produced minus the duplicates. The
  caller frees the list. }
function SpxGenerateUnique(const Tmpl: string; const Ctx: TSpxContext; Count: Integer;
  SeedBase: LongWord; const Opts: TSpxDedupeOpts;
  out Report: TSpxBatchReport): TSpxVariantList;

{ The same filter over variants that already exist -- for a set the user is looking at, or
  one loaded from elsewhere. Keeps the first of every near-identical group. The caller frees
  the list; the input is left alone. }
function SpxDedupeList(Variants: TSpxVariantList; const Opts: TSpxDedupeOpts;
  out Dropped: Integer): TSpxVariantList;

implementation

function SpxDefaultDedupeOpts: TSpxDedupeOpts;
begin
  Result.ShingleSize := 4;
  Result.Threshold := 0.75;
  Result.RetryBudget := -1;   { -1 = twice the request, resolved when the count is known }
end;

{ FNV-1a, 32-bit. Chosen for being three lines and having no state to get wrong; a collision
  would make two different shingles look equal, which at 32 bits over a document's worth of
  shingles is rare enough to cost nothing but is worth knowing about.

  Its multiply is SUPPOSED to wrap -- that is the whole mixing step -- so overflow and range
  checks are lifted around it and restored to whatever the build had, exactly as the engine
  does for mulberry32's mixer, and for the same reason: the checked twin of the suite raised
  EIntOverflow here on the first run. Lifted around this arithmetic only, so a host that
  compiles with checks on keeps them everywhere else. }
{$IFOPT Q+}{$DEFINE SPX_Q_WAS_ON}{$Q-}{$ENDIF}
{$IFOPT R+}{$DEFINE SPX_R_WAS_ON}{$R-}{$ENDIF}

function HashRun(const S: string; Start, Len: Integer): LongWord;
var i: Integer;
begin
  Result := 2166136261;
  for i := Start to Start + Len - 1 do
  begin
    Result := Result xor LongWord(Ord(S[i]));
    Result := Result * 16777619;
  end;
end;

{ The seed step, in the same guarded region and for the same reason: at the top of the range
  a seed wraps to zero, which is what a seed is FOR -- an identifier for regenerating one
  row, not a counter. Unguarded it raises in a checked build, which is how this was found. }
function StepSeed(S: LongWord): LongWord;
begin
  Result := S + 1;
end;

{$IFDEF SPX_R_WAS_ON}{$R+}{$UNDEF SPX_R_WAS_ON}{$ENDIF}
{$IFDEF SPX_Q_WAS_ON}{$Q+}{$UNDEF SPX_Q_WAS_ON}{$ENDIF}

{ Case folded through the engine's own table, so two renders of one template that differ only
  in what its capitalisation pass did are one text here. Uppercase rather than lowercase
  because that is the direction the engine implements (SpUpperCodePoint) -- for an equality
  fold either works, and reusing the engine's mapping means the two never disagree about a
  character. }
function FoldCase(const S: string): string;
var i, cpLen: Integer; cp: LongWord;
begin
  Result := '';
  i := 1;
  while i <= Length(S) do
  begin
    cp := SpCodePointAt(S, i, cpLen);
    { ASCII is the overwhelming majority of a template's bytes -- markup, spaces, digits --
      and a table lookup for each would cost more than the fold saves. }
    if cp < 128 then
    begin
      if (S[i] >= 'a') and (S[i] <= 'z') then
        Result := Result + Chr(Ord(S[i]) - 32)
      else
        Result := Result + S[i];
    end
    else
      Result := Result + SpUpperCodePoint(cp);
    Inc(i, cpLen);
  end;
end;

procedure SortHashes(var H: TSpxHashes);

  { Quicksort with a median-of-three pivot. The first version was an insertion sort, on the
    stated assumption that a variant carries "hundreds of shingles" -- measured, a 21 KB
    variant carries 1085 and a 250 KB one 4181, and the insertion sort spent 442 ms on the
    latter against 0 ms here. At N = 1000 that assumption cost eight seconds per batch, all
    of it in sorting. }
  procedure QSort(L, R: Integer);
  var i, j: Integer; pivot, t: LongWord;
  begin
    while L < R do
    begin
      i := L;
      j := R;
      pivot := H[(L + R) div 2];
      while i <= j do
      begin
        while H[i] < pivot do Inc(i);
        while H[j] > pivot do Dec(j);
        if i <= j then
        begin
          t := H[i]; H[i] := H[j]; H[j] := t;
          Inc(i);
          Dec(j);
        end;
      end;
      { Recurse into the smaller side and loop on the larger: the stack stays O(log n) even
        on input that would otherwise walk it down one element at a time. }
      if (j - L) < (R - i) then
      begin
        QSort(L, j);
        L := i;
      end
      else
      begin
        QSort(i, R);
        R := j;
      end;
    end;
  end;

begin
  if Length(H) > 1 then QSort(0, High(H));
end;

function SpxShingles(const Text: string; Size: Integer): TSpxHashes;
var
  lower: string;
  starts, lens: array of Integer;
  n, i, j, count_, w, runStart, runLen: Integer;
  buf: string;
begin
  Result := nil;
  if Size < 1 then Size := 1;
  lower := FoldCase(Text);

  { Word boundaries first, so a shingle can be hashed straight out of one joined buffer
    rather than by concatenating strings k at a time. }
  starts := nil;
  lens := nil;
  n := 0;
  i := 1;
  while i <= Length(lower) do
  begin
    while (i <= Length(lower)) and (lower[i] <= ' ') do Inc(i);
    if i > Length(lower) then Break;
    runStart := i;
    while (i <= Length(lower)) and (lower[i] > ' ') do Inc(i);
    runLen := i - runStart;
    if n >= Length(starts) then
    begin
      SetLength(starts, (n + 1) * 2);
      SetLength(lens, (n + 1) * 2);
    end;
    starts[n] := runStart;
    lens[n] := runLen;
    Inc(n);
  end;

  if n = 0 then Exit;                    { nothing but whitespace has no fingerprint }
  if n < Size then Size := n;            { a short text is one shingle, not none }

  count_ := n - Size + 1;
  SetLength(Result, count_);
  for i := 0 to count_ - 1 do
  begin
    buf := '';
    for w := i to i + Size - 1 do
    begin
      if w > i then buf := buf + ' ';
      buf := buf + Copy(lower, starts[w], lens[w]);
    end;
    Result[i] := HashRun(buf, 1, Length(buf));
  end;

  { Sorted and deduplicated: a repeated phrase must count once, or a text that says the same
    sentence twice would drag its own overlap around. }
  SortHashes(Result);
  j := 0;
  for i := 1 to High(Result) do
    if Result[i] <> Result[j] then
    begin
      Inc(j);
      Result[j] := Result[i];
    end;
  SetLength(Result, j + 1);
end;

function SpxSimilarity(const A, B: TSpxHashes): Double;
var i, j, both, total: Integer;
begin
  if (Length(A) = 0) and (Length(B) = 0) then Exit(1.0);
  if (Length(A) = 0) or (Length(B) = 0) then Exit(0.0);
  i := 0;
  j := 0;
  both := 0;
  total := 0;
  { A linear merge over two sorted sets: every step consumes at least one side, so this is
    O(|A| + |B|) rather than the nested scan the same job invites. }
  while (i < Length(A)) and (j < Length(B)) do
  begin
    Inc(total);
    if A[i] = B[j] then
    begin
      Inc(both);
      Inc(i);
      Inc(j);
    end
    else if A[i] < B[j] then
      Inc(i)
    else
      Inc(j);
  end;
  total := total + (Length(A) - i) + (Length(B) - j);
  if total = 0 then Exit(1.0);
  Result := both / total;
end;

{ The comparison the whole unit exists for, kept in one place: is this text within the
  threshold of anything already kept? }
function TooCloseToAny(const Fp: TSpxHashes; const Kept: array of TSpxHashes;
  KeptCount: Integer; Threshold: Double): Boolean;
var i: Integer;
begin
  for i := 0 to KeptCount - 1 do
    if SpxSimilarity(Fp, Kept[i]) >= Threshold then Exit(True);
  Result := False;
end;

function ResolveOpts(const Opts: TSpxDedupeOpts; Count: Integer): TSpxDedupeOpts;
begin
  Result := Opts;
  if Result.ShingleSize < 1 then Result.ShingleSize := 1;
  { A threshold of 0 would call every pair a duplicate and return one variant; refusing it is
    kinder than obeying it, and 1.0 stays meaningful (identical fingerprints only). }
  if Result.Threshold <= 0 then Result.Threshold := 0.01;
  if Result.Threshold > 1 then Result.Threshold := 1;
  { Twice the request by default, and capped rather than multiplied blindly: Count comes from
    a caller, and Count * 2 overflows above MaxInt div 2 -- unreachable from a spin box, but
    unguarded Integer arithmetic in a unit whose checked twin is part of the gate. }
  if Result.RetryBudget < 0 then
  begin
    if Count > MaxInt div 4 then Result.RetryBudget := MaxInt div 2
    else Result.RetryBudget := Count * 2;
  end;
end;

function SpxGenerateUnique(const Tmpl: string; const Ctx: TSpxContext; Count: Integer;
  SeedBase: LongWord; const Opts: TSpxDedupeOpts;
  out Report: TSpxBatchReport): TSpxVariantList;
var
  o: TSpxDedupeOpts;
  kept: array of TSpxHashes;
  fp: TSpxHashes;
  v: TSpxVariant;
  batch: TSpxVariantList;
  seed: LongWord;
  tried, spent: Integer;
begin
  Result := TSpxVariantList.Create;
  o := ResolveOpts(Opts, Count);

  Report.Requested := Count;
  Report.Generated := 0;
  Report.Dropped := 0;
  Report.Tried := 0;
  Report.SeedBase := SeedBase;
  Report.NextSeed := SeedBase;
  Report.Exhausted := False;
  if Count <= 0 then Exit;

  SetLength(kept, Count);
  seed := SeedBase;
  tried := 0;
  { N seeds for the set, plus the budget for replacing what gets dropped. Bounded here rather
    than per-drop: a drop is not what should stop the loop -- running out of seeds is. }
  spent := Count + o.RetryBudget;

  while (Result.Count < Count) and (tried < spent) do
  begin
    { One seed at a time rather than a batch up front: the number of renders needed is not
      known until the duplicates are counted, and a render is the expensive part. }
    batch := SpxRenderBatch(Tmpl, Ctx, 1, seed);
    try
      if batch.Count = 0 then Break;
      v := batch[0];
    finally
      batch.Free;
    end;
    Inc(tried);
    seed := StepSeed(seed);
    Report.NextSeed := seed;

    fp := SpxShingles(v.Text, o.ShingleSize);
    if TooCloseToAny(fp, kept, Result.Count, o.Threshold) then
    begin
      Inc(Report.Dropped);
      Continue;
    end;

    kept[Result.Count] := fp;
    Result.Add(v);
  end;

  Report.Generated := Result.Count;
  Report.Tried := tried;
  { A short set is said out loud rather than left to be inferred by comparing two numbers:
    it means the template could not produce what was asked for within the seeds allowed, and
    that is the sentence the author needs to read. }
  Report.Exhausted := Report.Generated < Report.Requested;
end;

function SpxDedupeList(Variants: TSpxVariantList; const Opts: TSpxDedupeOpts;
  out Dropped: Integer): TSpxVariantList;
var
  o: TSpxDedupeOpts;
  kept: array of TSpxHashes;
  fp: TSpxHashes;
  i: Integer;
begin
  Result := TSpxVariantList.Create;
  Dropped := 0;
  if Variants = nil then Exit;
  o := ResolveOpts(Opts, Variants.Count);
  SetLength(kept, Variants.Count);
  for i := 0 to Variants.Count - 1 do
  begin
    fp := SpxShingles(Variants[i].Text, o.ShingleSize);
    if TooCloseToAny(fp, kept, Result.Count, o.Threshold) then
    begin
      Inc(Dropped);
      Continue;
    end;
    kept[Result.Count] := fp;
    Result.Add(Variants[i]);
  end;
end;

end.
