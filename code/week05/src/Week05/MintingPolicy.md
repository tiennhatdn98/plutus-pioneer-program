Một transaction không thể tạo hoặc xóa token. Mọi thứ đi vào và cũng đi ra, ngoại trừ phí. Luôn luôn có cảm giác rằng lovelace đã được trả với mỗi transaction. Phí phụ thuộc vào độ lớn của tx, độ phức tạp mà validation script thực thi và bộ nhớ được tiêu thụ của script.

Nhưng nếu đó là cả một câu chuyện thì chúng ta không thể tạo native tokens. Và đó là nơi minting policies và những thứ liên quan đến currency symbol ra đời

Lý do mà currency symbol bao gồm các chữ số hexa là đó chính là mã hash của script. Và script này được gọi là minting policy, và nếu chúng ta có một tx nơi mà chúng ta dự tính tạo hoặc burn token. Với mỗi native token mà chúng ta tạo hoặc burn, thì currency symbol sẽ được tra cứu. Vì thế, script tương ứng cũng phải được chứa trong tx. Và script này được thực thi cùng với các validation script khác.

Và tương tự như các validation scripts mà chúng ta đã thấy để validate input, mục đích của các minting script này là để quyết định lúc nào tx này có quyền mint hoặc burn token. Ada cũng phù hợp với vụ ni. Hãy nhớ rằng currency symbol của Ada chỉ là chuỗi rỗng, không phải mã hash của script. Vì thế mà không có script nào được hash từ một chuỗi rỗng, nên cũng không có script nào cho phép mint hoặc burn Ada, điều đó cũng có nghĩa là Ada không bao giờ có thể được mint hoặc burn.

Tất cả Ada tồn tại từ Genesis tx và tổng số lượng Ada trong hệ thống được fix cứng và không bao giờ thay đổi. Chỉ những custom native token có thể tùy chỉnh được minting policies.

Nhìn vào ví dụ về minting policy tiếp theo và sẽ thấy rằng nó tương tự như validation script, nhưng không giống hệt nhau.

Trước khi viết một minting policty đầu tiên, hãy nhắc lại một cách ngắn gọn cách hoạt động của validation

Khi chúng ta không có public key address, nhưng script address và một UTxO nằm trong script address đó và một transaction đang cố consume UTxO đó như một input, thì với mỗi script input đó, script tương ứng sẽ chạy validation script.

Validation script đó, với input là datum từ UTxO, redeemer từ input và context

`ScriptContext` có 2 trường:

```haskell
data ScriptContext = ScriptContext
  { scriptContextTxInfo :: TxInfo
  , scriptContextPurpose :: ScriptPurpose
  }
```

Một trong những trường đó là `ScriptPurpose`, tất cả những thế mà chúng ta thấy tới bây giờ là kiểu Spending

```haskell
data ScriptPurpose = Minting CurrencySymbol
                   | Spending TxOutRef
                   | Rewarding StakingCrendential
                   | Certifying DCert
```

Một trường khác thuộc kiểu `TxInfo`, nó chứa tất cả thông tin về tx

```haskell
data TxInfo = TxInfo
    { txInfoInputs      :: [TxInInfo] -- ^ Transaction inputs
    , txInfoInputsFees  :: [TxInInfo]     -- ^ Transaction inputs designated to pay fees
    , txInfoOutputs     :: [TxOut] -- ^ Transaction outputs
    , txInfoFee         :: Value -- ^ The fee paid by this transaction.
    , txInfoForge       :: Value -- ^ The 'Value' forged by this transaction.
    , txInfoDCert       :: [DCert] -- ^ Digests of certificates included in this transaction
    , txInfoWdrl        :: [(StakingCredential, Integer)] -- ^ Withdrawals
    , txInfoValidRange  :: SlotRange -- ^ The valid range for the transaction.
    , txInfoSignatories :: [PubKeyHash] -- ^ Signatures provided with the transaction, attested that they all signed the tx
    , txInfoData        :: [(DatumHash, Datum)]
    , txInfoId          :: TxId
    -- ^ Hash of the pending transaction (excluding witnesses)
    } deriving (Generic)
```

Đối với minting policies, sẽ có trigger nếu trường `txInfoForge` của tx chứa giá trị khác 0. Trong tất cả các tx chúng ta đã thấy, giá trị của trường này là 0 - chúng ta không tạo hoặc hủy bất kỳ token nào.

Nếu nó là non-zero, thì với mỗi currency symbol được chứa trong Value, thì minting policy script tương ứng sẽ được chạy

Nhưng trái lại validation script có 3 inputs: datum, redeemer và context, minting policy script chỉ có 1 input là context. Và nó cùng context như chúng ta đã có trước đó - `ScriptContext`. Sẽ vô nghĩa nếu có datum, vì nó thuộc về UTxO, và cũng vô nghĩa nếu có redeemer, vì nó thuộc về validation script. Minting policy thuộc về chính transaction, không phải input hoặc output cụ thể.

Về phần `ScriptPurpose`, đây sẽ không phải là `Spending` như trước đây nữa mà sẽ là `Minting`.

Example 1 - Free
On chain

```haskell
mkValidator :: Datum -> Redeemer -> ScriptContext -> Bool
```

Chúng ta cũng đã thấy low-level version nơi có 3 tham số Data và return Unit. Và chúng ta đã thấy có thể có thêm các tham số trước datum, nếu chúng ta viết script theo dạng tham số hóa (parameterized script)

Chúng ta cũng có tể tham số hóa minting policy script và chúng ta sẽ thấy ở example sau. Nhưng đầu tiên chúng ta sẽ nhìn vào script chưa tham số hóa

Đầu tiên, đổi tên function thành `mkPolicy`, xóa datum và redeemer và viết đơn giản nhất có thể

```haskell
mkPolicy :: ScriptContext -> Bool
mkPolicy _ = True
```

Policy này từ chối context và luôn luôn trả về True. Nó sẽ cho phép mint hoặc burn token bất kỳ và tên của token thuộc currency symbol cũng liên quan đến policy này.

Hãy nhớ rằng, khi chúng ta viết một validator, chúng ta cần sử dụng Template Haskell để biên dịch function này thành Plutus code. Chúng ta cần làm điều tương tự với minting policy

```haskell
policy :: Scripts.MonetaryPolicy
policy = mkMonetaryPolicyScript
  $$(PlutusTx.compile [|| Scripts.wrapMonetaryPolicy mkPolicy ||])
```

Và trước đó, chúng ta cần làm cho `mkPolicy` function INLINABLE

```haskell
{-# INLINABLE mkPolicy #-}
mkPolicy :: ScriptContext -> Bool
mkPolicy _ = True
```

Bây giờ, chúng ta có một policy, chúng ta có thể lấy currency symbol từ policy

```haskell
curSymbol :: CurrencySymbol
curSymbol = scriptCurrencySymbol policy
```

Chúng ta có thể nhìn vào REPL:

```console
Prelude Week05.Free> curSymbol
e01824b4319351c40b5ec727fff328a82076b1474a6bad6c8e8a2cd835cc6aaf
```

Chúng ta đã hoàn thành phần on-chain cho một mintin policy đơn giản. Nhưng để chạy thử và tương tác với nó, chúng ta cần phần off-chain.

Off chain

Phần off-chain sẽ làm thứ gì? Nó sẽ cho phép các ví bất kỳ mint hoặc burn token của currency symbol.

Chúng ta có currency symbol, vì vậy thứ còn thiếu là token name và số lượng mà chúng ta muốn mint hoặc burn. Để làm điều này, chúng ta sẽ định nghĩa kiểu dữ liệu `MintParams`

```haskell
data MintParams = MintParams
  { mpTokenName :: !TokenName
  , mpAmount    :: !Intege
  } deriving (Generic, ToJSON, FromJSON, ToSchema)
```

Chúng ta cần 2 trường: `mpTokenName` và `mpAmount`. Ý tưởng là nếu `mpAmount` dương, chúng ta sẽ tạo token, và nếu nó âm, chúng ta sẽ burn token.

Bước tiếp theo là tạo schema. Hãy nhớ rằng một trong những tham số của Contact monad là schema được định nghĩa các hành động có sẵn mà ta có thể tương tác.

```haskell
type FreeSchema =
  BlockchainActions
  .\/ Endpoint "mint" MintParams
```

Như mọi khi, chúng ta có `BlockchainActions` giúp chúng ta truy cập những thứ chung chung như là lấy public key. Và chúng ta đã thêm một endpoint `mint` sử dụng toán tử type-level.

Bây giờ, chúng ta xem xét contract

```haskell
mint :: MintParams -> Contract w FreeSchema Text ()
```

Lần trước, chúng ta không đi sâu vào phần off-chain của contract. Nhưng, khi chúng ta đã hiểu về Contract monad ở bài học trước, chúng ta sẵn sàng đi sâu chi tiết vào nó.

Nhớ rằng Contract monad có 4 tham số.

Tham số đầu tiên là writer monad cho phép chúng ta sử dụng function `tell`. Bằng cách để tham số này là `w`, chúng ta chỉ định rằng chúng ta sẽ không sử dụng tham số này, chúng ta sẽ không `tell` bất kỳ một state nào.

Tiếp theo là schema mà chúng ta muốn đề cập. Như đã nói ở trên, bằng cách sử dụng `FreeSchema` chúng ta có thể try cập đến các actions của các block thông thường như là `mint` endpoint.

Tham số thứ ba là kiểu của error message, như chúng ta đã thấy, `Text` thường là một lựa chọn hợp lý.

Tham số cuối cùng là kiểu dữ liệu trả về, contract của chúng ta chỉ trả về kiểu Unit.

Bây giờ là body của function. Khi Contact là một monad, chúng ta có thể sử dụng `do` notation

```haskell
mint mp = do
  let val     = Value.singleton curSymBol (mpTokenName mp) (mpAmount mp)
      lookups = Constrains.monetaryPolicy policy
      tx      = Constrains.mustForgeValue val
  ledgerTx <- submitTxConstraintsWith @Void lookups tx
  void $ awaitTxConfirmed $ txId ledgerTx
  Contract.logInfo @String $ printf "forged %s" (show val)
```

Điều đầu tiên chúng ta định nghĩa là value mà ta muốn forge. Chúng ta sử dụng `singleton` function mà chúng ta đã thử ở REPL trước.

Tham số trong `singleton` function là currency symbol mà thể hiện mã hash của minting policy, thêm vào đó là token name và số lượng được lấy từ MintParams.

Chúng ta sẽ bỏ qua `lookups` và chuyển sang `tx`.

Một trong những mục đích chính của Contract monad là để tạo (construct) và submit các transaction. Con đường (path) mà Plutus team thực hiện là cung cấp một cách để xác định ràng buộc (constraint) của transaction đã định nghĩa. Plutus libraries sẽ quan tâm đến việc tạo (construct) một transaction đúng (nếu có thể). Điều này trái với việc yêu cầu tất cả inputs và outputs một cách thủ công, nó rất tẻ nhạt khi nhiều yêu cầu chẳng hạn như trả lại tiền thối cho sending wallet thường giống nhau.

Những điều kiện này thường có tên bắt đầu bởi `must`. Có những thứ như `mustSpendScriptOutput`, `mustPayToPublicKey` và tất cả các loại điều kiện có thể đặt trong một điều kiện.

Ở ví dụ trên, chúng ta sử dụng `mustForgeValue` và truyền `val` vào đã được khai báo trước đó. Kết quả của việc foring token được xác định bởi `val` là chúng sẽ nằm trong ví của chúng ta.

Một khi condition được định nghĩa, bạn cần gọi function để submit transaction. Có rất nhiều function như vậy, nhưng trong trường hợp này, function phù hợp là `submitTxConstraintsWith`.

Những function `submitTx` này sẽ lấy các condition đã khai báo mà transaction thỏa mãn, và sau đó chúng sẽ construct một transaction phù hợp với các conditions đó. Trường hợp của chúng ta, condition duy nhât là chúng ta muốn forge value.

Những gì mà `submitTxConstrainsWith` cần làm để tạo một valid transaction là gì? Ví dụ cần bằng inputs và outputs. Trong trường hợp này, vì chúng ta luôn luôn có transaction fees, nên chúng ta cần một input bao gồm các transaction fees. Vì thế, để tạo transaction, function sẽ nhìn vào UTxO và tìm một hoặc nhiều hơn UTxO có thể bao gòmo transaction fees và sử dụng chúng như là một input của transaction.

Hơn nữa, nếu chúng ta forge value (nếu `mpAmount` dương), thì token phải bắt nguồn từ nơi nào đó. Trong trường hợp này, function `submitTxConstraintsWith` sẽ tìm một input trong ví của chúng ta để lấy token.

Function submit có thể thất bại. Ví dụ, nếu chúng ta muốn chuyển tiền cho ai đó, nhưng chúng ta không có đủ tiền trong ví, thì sẽ thất bại. Hoặc, nếu chúng ta muốn burn token mà chúng ta không có, nó cũng sẽ thất bại. Khi thất bại, một biệt lệ sẽ được thrown với kiểu error message là Text.

Quay trở lại với `lookups`. Để thỏa mãn condition ở function `mustForgeValue` và construct một transaction, đôi lúc library cần một số thông tin bổ sung. Trong trường hợp này, để validate một transaction forge value, các node validate transaction cần phải chạy policty script.

Nhưng, currency symbol chỉ là mã hash của policy script. Để chạy script của nó, nó cần phải được bao gồm trong transaction. Có nghĩa là, ở bước construct transaction, khi thuật toán thấy ràng buộc `mustForgeValue`, nó biết rằng nó cần phải đính kèm policy script tương ứng vào transaction.

Để làm cho thuật toán biết được policy script đang ở đâu, chúng ta có thể cho nó một số gợi ý, và đó là tra cứu (lookups). Có nhiều cách lookups mà ta có thể sử dụng, bạn có thể đưa UTxOs, validator scripts và chúng ta đã làm, bạn cũng có thể đưa monetary policy scripts.

Trong trường hợp của chúng ta, thứ duy nhất chúng ta cần cung cấp khi lookups là policy mà chúng ta đã định nghĩa trước đó trong script.

Có rất nhiều biến thể của `submitTxConstraintsWith` mà không có `with` để không cần lookups, chúng ta đã thấy ở các bài học trước.

Cuối cùng `@Void` ở dòng:

```haskell
ledgerTx <- submitTxConstraintsWith @Void lookups tx
```

Hầu hết các constraints functions đều hướng tới việc sử dụng một validator script cụ thể. Thông thường chúng ta sẽ rơi vào trường hợp là chúng ta đang làm việc với một smart contract. Và smart contract đó có datum và redeemer type, và hầu hết các constraints functions đều tham số đến datum và redeemer type. Trong trường hợp đó bạn có thể sử dụng trực tiếp datum type mà không cần chuyển nó sang Plutus Datum type.

Nhưng trong trường hợp này, chúng ta không làm điều đó. Chúng ta không có bất kỳ validator script nào. Có nghĩa là `submitTxConstraintsWith` sẽ không biết được type nào được dùng cho datum và redeemer vì chúng ta không có chúng trong ví dụ này. Vì vậy, trường hợp này chúng ta cần nói cho compiler biết rằng type nào chúng ta sử dụng. Chúng ta không quan tâm, vì không có datum và redeemer, nên chúng ta sử dụng type `Void`.

Let's evaluate on Plutus Playground
![alt text for screen readers](/MintToken.png "Mint token").

It's 444 so that's wallet 2, the minting value 2, the 100 ADA go in. 2533 lovelace fee. The rest goes out, except here us another UTxO containing the newly minted 444 tokens and an additional 2 ADA. And that is due to something called min UTxO. So in Cardano UTxOs must have a minimum value. So in the playground this value is 2 ADA. Therefore it's not enough to just have these 444 tokens. Additionally, there must be at least 2 ADA. Then the other transaction that happens at slot one, it's the same for wallet 1. And now we mint 555 tokens. You can also see that minting happens, minting or burning in the middle in the transaction here in this forge block. It mentions the currency symbol policy, the token name and the amount.

![alt text for screen readers](/BurnToken.png "Burn token").

And finally in slot 2, we see the burning. So here inputs are ADA UTxO and the one holding, the 555 tokens and these min UTxO 2 ADA. Then the transaction burns 222 tokens. And we have one UTxO output, the remaining ADA and 333 remaining tokens.

So we can also check the final balances. And in the diagram, we don't see the token because it's so small, the amount comparision to the 100 million lovelace but here in the table we see it, that wallet 2 ends up with 444 and wallet 1 with 333 exactly as in the emulator trace
