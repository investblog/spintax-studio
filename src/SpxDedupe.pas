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

  { How two variants are compared.

    `Exact` is byte equality and nothing else -- fast, and the honest answer when the author
    only wants literal repeats gone. It is NOT the same as shingles at a threshold of 1.0:
    a fingerprint is a SET, so two texts whose sentences are shuffled have identical
    fingerprints and different bytes.

    `Off` keeps everything, for a set that will be filtered somewhere else. }
  TSpxDedupeMode = (spxDedupeOff, spxDedupeExact, spxDedupeShingles);

  { What counts as "the same text". }
  TSpxDedupeOpts = record
    { Which comparison is used at all. The shingle settings below are ignored by the other
      two modes. }
    Mode: TSpxDedupeMode;
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

{ The options with their clamps applied, and the budget resolved for a request of Count --
  exported because a caller driving the loop itself (the export tab, through the engine
  thread) has to compute the same limit from the same rule, and a second copy of "twice the
  request unless it overflows" is one copy too many. }
function SpxResolveDedupeOpts(const Opts: TSpxDedupeOpts; Count: Integer): TSpxDedupeOpts;

{ The next seed. A LongWord wraps at the top of the range, which is the intended behaviour --
  a seed identifies a row, it does not count anything -- but the arithmetic raises in a build
  with overflow checks on unless it is done here, inside the guarded region. }
function SpxNextSeed(Seed: LongWord): LongWord;

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

  MARKUP IS REMOVED BEFORE THE WORDS ARE COUNTED, and that is not a nicety about fairness --
  it is what makes the measure work on a template that is mostly tags. Measured on a
  120-row listing whose tags carry no whitespace: counting them, the fingerprint is 236
  shingles and every pair scores 0.001; without them it is 500 and the pairs land at 0.058.
  On the same listing with no spaces anywhere the whole document is ONE word and the
  fingerprint collapses to a single shingle -- the dedup silently stops working and reports
  every variant as unique, at any threshold. On prose the difference is nothing: the demo is
  identical either way and an 18 KB article moves from 0.202 to 0.201. GTW does the same and
  says so on its dialog; this is the measurement behind agreeing with it.

  Text shorter than k words yields one shingle, so short variants still compare instead of
  silently matching everything. }
function SpxShingles(const Text: string; Size: Integer): TSpxHashes;

{ Jaccard overlap of two fingerprints: |A and B| / |A or B|, 0..1. Two empty texts are
  identical (1.0); one empty against a non-empty one shares nothing (0.0). }
function SpxSimilarity(const A, B: TSpxHashes): Double;

type
  { The same rule, one variant at a time.

    SpxGenerateUnique renders its whole set inside one call, which is right for a script and
    wrong for a window: with the default budget that is up to 3N renders on the single engine
    thread, measured at 61 seconds for N = 200, with nothing to show and no way to stop. The
    export tab drives the loop itself -- render a seed, offer it here, repeat -- so it can
    report progress, take a cancel, and let an interactive render in between.

    Holds fingerprints, not texts: the caller keeps whatever it accepted. }
  TSpxUniqueSet = class
  private
    FOpts: TSpxDedupeOpts;
    FKept: array of TSpxHashes;
    { Whole-text hashes, for the exact mode. A hash rather than the texts themselves: a
      thousand variants of an article is megabytes, and a 32-bit collision here costs one
      wrongly dropped variant out of a set that has a retry budget for exactly that. }
    FExact: array of LongWord;
    FCount: Integer;
  public
    constructor Create(const AOpts: TSpxDedupeOpts);
    { True when the text is far enough from everything kept so far, and then it is remembered
      as kept. False means it was a near-duplicate and nothing changed. }
    function Accept(const Text: string): Boolean;
    property Count: Integer read FCount;
  end;

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
  Result.Mode := spxDedupeShingles;
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

{ Tags out, a space in their place. A `<` only opens a tag when a name or a slash follows --
  the same rule the page view uses to decide whether output opens a document -- so `5 < 6`
  keeps its bracket and does not swallow the rest of the sentence. An unterminated `<b` at
  the very end is text, not a tag that ate the tail. }
function StripMarkup(const S: string): string;
var i, j: Integer; c: Char;
begin
  Result := '';
  i := 1;
  while i <= Length(S) do
  begin
    if (S[i] = '<') and (i < Length(S)) then
    begin
      c := S[i + 1];
      if ((c >= 'A') and (c <= 'Z')) or ((c >= 'a') and (c <= 'z')) or
         (c = '/') or (c = '!') then
      begin
        j := i + 1;
        while (j <= Length(S)) and (S[j] <> '>') do Inc(j);
        if j <= Length(S) then
        begin
          { A space, not nothing: `a</b><b>b` is two words, and closing them up would make
            it one. }
          Result := Result + ' ';
          i := j + 1;
          Continue;
        end;
      end;
    end;
    Result := Result + S[i];
    Inc(i);
  end;
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
  lower := FoldCase(StripMarkup(Text));

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

function SpxResolveDedupeOpts(const Opts: TSpxDedupeOpts; Count: Integer): TSpxDedupeOpts;
begin
  Result := ResolveOpts(Opts, Count);
end;

function SpxNextSeed(Seed: LongWord): LongWord;
begin
  Result := StepSeed(Seed);
end;

constructor TSpxUniqueSet.Create(const AOpts: TSpxDedupeOpts);
begin
  inherited Create;
  { Resolved with a count of zero: the budget belongs to the caller's loop here, not to this
    object, and the clamps on size and threshold are what matter. }
  FOpts := ResolveOpts(AOpts, 0);
  FCount := 0;
end;

function TSpxUniqueSet.Accept(const Text: string): Boolean;
var fp: TSpxHashes; h: LongWord; i: Integer;
begin
  case FOpts.Mode of
    spxDedupeOff:
      begin
        { Counted, so a caller reading Count still learns how many went by. }
        Inc(FCount);
        Exit(True);
      end;
    spxDedupeExact:
      begin
        h := HashRun(Text, 1, Length(Text));
        for i := 0 to FCount - 1 do
          if FExact[i] = h then Exit(False);
        if FCount >= Length(FExact) then SetLength(FExact, (FCount + 1) * 2);
        FExact[FCount] := h;
        Inc(FCount);
        Exit(True);
      end;
  end;

  fp := SpxShingles(Text, FOpts.ShingleSize);
  Result := not TooCloseToAny(fp, FKept, FCount, FOpts.Threshold);
  if not Result then Exit;
  if FCount >= Length(FKept) then SetLength(FKept, (FCount + 1) * 2);
  FKept[FCount] := fp;
  Inc(FCount);
end;

function SpxGenerateUnique(const Tmpl: string; const Ctx: TSpxContext; Count: Integer;
  SeedBase: LongWord; const Opts: TSpxDedupeOpts;
  out Report: TSpxBatchReport): TSpxVariantList;
var
  o: TSpxDedupeOpts;
  uniq: TSpxUniqueSet;
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

  seed := SeedBase;
  tried := 0;
  { N seeds for the set, plus the budget for replacing what gets dropped. Bounded here rather
    than per-drop: a drop is not what should stop the loop -- running out of seeds is. }
  spent := Count + o.RetryBudget;

  { The rule itself lives in TSpxUniqueSet, so this loop and the window's own loop can never
    drift apart about what counts as a duplicate. }
  uniq := TSpxUniqueSet.Create(o);
  try
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

      if uniq.Accept(v.Text) then
        Result.Add(v)
      else
        Inc(Report.Dropped);
    end;
  finally
    uniq.Free;
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
  uniq: TSpxUniqueSet;
  i: Integer;
begin
  Result := TSpxVariantList.Create;
  Dropped := 0;
  if Variants = nil then Exit;
  o := ResolveOpts(Opts, Variants.Count);
  uniq := TSpxUniqueSet.Create(o);
  try
    for i := 0 to Variants.Count - 1 do
      if uniq.Accept(Variants[i].Text) then
        Result.Add(Variants[i])
      else
        Inc(Dropped);
  finally
    uniq.Free;
  end;
end;

end.
