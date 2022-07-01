Một transaction không thể tạo hoặc xóa token. Mọi thứ đi vào và cũng đi ra, ngoại trừ phí. Luôn luôn có cảm giác rằng lovelace đã được trả với mỗi transaction. Phí phụ thuộc vào độ lớn của tx và số bước mà validation script thực thi, bộ nhớ được tiêu thụ của script.

Nhưng nếu đó là cả một câu chuyện thì chúng ta không thể tạo native tokens. Và đó là nơi minting policies và những thứ liên quan đến currency symbol ra đời

Lý do mà currency symbol bao gồm các chữ số hexa là đó chính là mã hash của script. Và script này được gọi là minting policy, và nếu chúng ta có một tx nơi mà chúng ta dự tính tạo hoặc burn token, với mỗi native token mà chúng ta tạo hoặc burn, thì currency symbol được tra cứu. Vì thế, script tương ứng cũng phải được chức trong tx. Và script này được thực thi cùng với các validation script khác.

Và tương tự như các validation scripts mà chúng ta đã thấy ở validate input, mục đích của các minting script này là để quyết định lúc nào tx này có quyền mint hoặc burn token. Ada cũng phù hợp với vụ ni. Hãy nhớ rằng currency symbol của Ada chỉ là chuỗi rỗng, không phải mã hash của script. Vì thế mà không có scruot nào được hash từ một chuỗi rỗng, nên cũng không có script nào được cho phép để mint hoặc burn Ada, điều đó cũng có nghĩa là Ada không bao giờ có thể được mint hoặc burn.

Tất cả Ada tồn tại từ Genesis tx và tổng số lượng Ada trong hệ thống được fix cứng và không bao giờ thay đổi. Chỉ những custom native token có thể có các custom minting policies.

Nhìn vào ví dụ về minting policy tiếp theo và sẽ thấy rằng nó tương tự như validation script, nhưng không giống hệt nhau.

Trước khi viết một minting policty đầu tiên, hãy nhắc lại một cách ngắn gọn cách hoạt động của validation

Khi chúng ta không có public key address, nhưng script address và một UTxO ở trong địa chỉ đó, với bất cứ một tx nào consume UTxO đó, thì validation script sẽ được thực thi

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
