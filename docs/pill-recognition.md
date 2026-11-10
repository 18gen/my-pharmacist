# How pill recognition works

[日本語](#ピル認識の仕組み) below.

Recognition is not "just the OpenAI API". There are three steps, and OpenAI does only
the second.

| Step | Where it runs | What happens |
|---|---|---|
| 1. Find and cut out | On the phone | Each pill in the photo is found and cut out as its own picture. |
| 2. Recognize | Server, then OpenAI | Each picture is compared with the person's medications and their photos. |
| 3. Decide | On the phone | The schedule decides take now / don't take now / unknown. |

## 1. Find and cut out

Code: `PillFinder`, `PillLocator`, `PillRules`, `BlobSplitter`, `SurfaceOutliers`.

- **Two ways of finding, used together:**
  - Apple's Vision lifts the separate objects from the photo.
  - The surface's colour (a hand, a table) is learned from the photo itself, and what
    differs from it is marked. This still sees the pills when Vision takes the hand and
    everything on it for one object.
- **Each area is judged** by its size in millimetres, how thin it is, how well it fills
  its outline, and its dents: a pill, pills joined, cut off by the photo's edge, or
  nothing to do with pills.
- **An area that looks joined** is settled in this order:
  1. Thin bridges (a shadow or crease between two pills) are removed. If two or more
     pills are left, those are the pills.
  2. It is cut at its narrow place. Clean pieces are the pills.
  3. Two middles that can't be cut apart are pills lying against each other: the photo
     is taken again ("Spread pills apart").
  4. One middle, no larger than a pill and filling at least 88% of its outline, is one
     pill with a rough outline: it is kept, and marked as doubted.
  5. Anything else is ignored.
- **One doubtful area turns the whole photo away**, with one thing to fix (spread apart,
  move closer, pills to the middle, plain surface). A pill that was never cut out can't
  be caught later.
- **The person confirms:** the photo is shown with every pill circled, and nothing is
  checked until they say every pill is circled.

The scan log (category "scan" in the Xcode console) has one line per area with these
numbers and what became of it.

## 2. Recognize

Code: `PillCropper`, `PillRecognizer`, `PillCheckClient`, `server/pill-check`.

- **Pictures:** each pill is cut from the full-size photo into a square of 384 to 512
  pixels, in the middle, turned to lie flat if it is long, with its surroundings dimmed.
  One more picture shows all the pills with numbers, so a missed pill can be noticed.
- **The request:** the server sends the pictures to an OpenAI vision model in one
  request, together with the names and reference photos of the person's medications.
- **The answer** can only be one of those medications or "none" (a strict JSON schema).
  The model also says what each picture shows: one pill, several pills, part of a pill,
  or no pill.
  - Unsure, several pills or part of a pill: the pill is unknown. For the last two the
    results also ask to scan again, as a pill may have gone unchecked.
  - No pill: an area the app itself doubted (step 1) is left out of the results. Any
    other area stays, as unknown.
- **A failed check** is never shown as a result. The person can try again on the same
  photo.

## 3. Decide

Code: `DoseSchedule`, `PillSetVerifier`.

The app, not the recognizer, decides from the medication and the time: take now (from
1 hour before a dose to 2 hours after), don't take now (too early, already scanned, too
late), or unknown.

## Putting your own model in step 2

Step 2 is behind one protocol:

```swift
protocol PillRecognizer: Sendable {
    func recognize(_ pictures: [CGImage], overview: CGImage?,
                   among medications: [Medication]) async throws(PillRecognitionFailure) -> PillReading
}
```

`PillPhotoAnalyzer(medications:recognizer:)` takes any recognizer. `PillCheckClient` is
the one the app uses now.

- **Input:** the pictures are already what a model needs: one pill each, centred, lying
  flat.
- **Model:** ePillID pairs reference images with consumer photos of the same pill, with
  very few images per pill. That suits an embedding (metric learning) model better than
  a classifier.
- **In the app:** embed each pill's picture and each medication's reference photos, and
  take the nearest medication only when it is clearly nearer than the rest. The person
  has a handful of medications, so it is a small closed set.
- **Unsure:** return nil for that pill (unknown), or pass the pictures on to
  `PillCheckClient`. Never guess.

---

# ピル認識の仕組み

「OpenAI API だけ」ではありません。3 段階あり、OpenAI が担当するのは 2 段階目だけです。

| 段階 | どこで動くか | 何をするか |
|---|---|---|
| ① 見つけて切り抜く | iPhone 内 | 写真から錠剤を 1 つずつ見つけ、1 錠ごとの画像を作る |
| ② どの薬か判定する | サーバー経由で OpenAI | 各画像を、登録した薬の写真と比べる |
| ③ 今飲むか決める | iPhone 内 | 服用スケジュールで「飲む/飲まない/不明」を決める |

## ① 見つけて切り抜く

コード:`PillFinder`、`PillLocator`、`PillRules`、`BlobSplitter`、`SurfaceOutliers`

- **2 つの方法を併用します。**
  - Apple の Vision で、写真から物体を 1 つずつ取り出す。
  - 手や机の色を写真から学習し、色が違う部分を取り出す。Vision が「手と錠剤を 1 つの物体」と見たときも、錠剤を見つけられます。
- **領域ごとに判定します。** 大きさ(mm)、細さ、輪郭の埋まり具合、へこみから、錠剤/くっついた錠剤/写真の端で切れている/錠剤ではない、のどれかに分けます。
- **くっついて見える領域**は、次の順で決めます。
  1. 細いつながり(錠剤の間の影やしわ)を取り除く。錠剤が 2 つ以上残れば、それが錠剤です。
  2. 細い部分で切り分ける。きれいに分かれれば、それが錠剤です。
  3. 中心が 2 つあり切り分けられないものは、重なった錠剤です。撮り直しになります(「Spread pills apart」)。
  4. 中心が 1 つで、錠剤 1 つの大きさ以下、かつ輪郭の 88% 以上を埋めていれば、輪郭が荒い 1 錠として残します(「疑わしい」印を付けます)。
  5. それ以外は無視します。
- **怪しい領域が 1 つでもあれば、写真全体を撮り直しにします。** 直すことを 1 つだけ伝えます。切り抜かれなかった錠剤は、後の段階では見つけられないためです。
- **利用者が確認します。** すべての錠剤に丸を付けた写真を見せ、「全部に丸が付いている」と答えるまで判定しません。

スキャンのログ(Xcode コンソールの "scan" カテゴリ)に、領域ごとの数値と結果が 1 行ずつ出ます。

## ② どの薬か判定する

コード:`PillCropper`、`PillRecognizer`、`PillCheckClient`、`server/pill-check`

- **画像:** 各錠剤を元の解像度から 384〜512 px の正方形に切り抜きます。錠剤は中央に置き、長い錠剤は横向きに回し、周囲を暗くします。全錠剤に番号を付けた写真も 1 枚作り、見落としに気づけるようにします。
- **リクエスト:** サーバーが、画像と登録薬の名前・参照写真を、OpenAI の画像モデルへ 1 回で送ります。
- **答え:** 登録薬のどれか、または「none」だけです(JSON スキーマで制限)。モデルは各画像に何が写っているかも答えます:錠剤 1 つ/複数の錠剤/錠剤の一部/錠剤ではない。
  - 自信が低い、複数の錠剤、錠剤の一部:その錠剤は「不明」になります。後の 2 つでは、未確認の錠剤があるかもしれないので、結果画面で再スキャンも促します。
  - 錠剤ではない:アプリ自身も疑っていた領域(①)なら、結果から外します。それ以外の領域は「不明」として残します。
- **判定に失敗したとき:** 結果としては表示しません。同じ写真でもう一度試せます。

## ③ 今飲むか決める

コード:`DoseSchedule`、`PillSetVerifier`

薬と時刻から、アプリが決めます。今飲む(服用時刻の 1 時間前から 2 時間後まで)/今は飲まない(早すぎる、スキャン済み、遅すぎる)/不明。AI は関与しません。

## ② を自作モデルに置き換える

② は 1 つのプロトコル(`PillRecognizer`、上のコード)の後ろにあります。`PillPhotoAnalyzer(medications:recognizer:)` に任意の実装を渡せます。今は `PillCheckClient` を使っています。

- **入力:** ① の画像(1 錠ずつ、中央、横向き)が、そのままモデルの入力になります。
- **モデル:** ePillID は、同じ錠剤の参照画像と利用者の写真を対にしたデータセットで、1 錠あたりの画像がごく少数です。分類器より埋め込み(metric learning)モデルが合います。
- **アプリ側:** 錠剤の画像と登録薬の参照写真をそれぞれ埋め込み、最も近い薬が他よりはっきり近いときだけ採用します。登録薬は数種類なので、小さな閉じた候補から選ぶ問題です。
- **自信がないとき:** その錠剤は nil(不明)を返すか、画像を `PillCheckClient` に渡します。推測はしません。
