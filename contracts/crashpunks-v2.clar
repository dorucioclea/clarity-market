;; Interface definitions
(impl-trait .nft-trait.nft-trait)
(impl-trait .operable.operable)
;; (impl-trait .transferable.transferable)

;; contract variables

(define-data-var administrator principal 'SP3N4AJFZZYC4BK99H53XP8KDGXFGQ2PRSQP2HGT6)
(define-data-var mint-price uint u1000)
(define-data-var mint-counter uint u0)
(define-data-var signer (buff 33) 0x02815c03f6d7181332afb1b0114f5a1c97286b6092957910ae3fab4006598aee1b)
(define-data-var is-collection bool true)

;; addresses to receive mint fee
(define-data-var collection-mint-addresses (list 4 principal) (list))
;; percent mint fee each address receives
(define-data-var collection-mint-shares (list 4 uint) (list))

;; addresses to receive royalty fees
;; first element at this list is ignored because the nft owner will be used
(define-data-var collection-royalty-addresses (list 10 principal) (list))
;; percent royalty fee each address receives
(define-data-var collection-royalty-shares (list 10 uint) (list))


;; constants
(define-constant percentage-with-twodp u10000000000)

(define-constant token-name "crashpunks-v2")
(define-constant token-symbol "CPS-v2")
(define-constant collection-max-supply u9216)

(define-constant ERR-NFT-DATA-NOT-FOUND (err u101))
(define-constant ERR-COULDNT-GET-V1-DATA (err u102))
(define-constant ERR-COULDNT-GET-NFT-OWNER (err u103))
(define-constant ERR-ASSET-NOT-REGISTERED (err u104))
(define-constant ERR-NFT-NOT-LISTED-FOR-SALE (err u105))
(define-constant ERR-PAYMENT-ADDRESS (err u106))
(define-constant ERR-NFT-LISTED (err u107))

(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-NOT-OWNER (err u402))
(define-constant ERR-NOT-V1-OWNER (err u403))
(define-constant ERR-NOT-ADMINISTRATOR (err u404))

(define-non-fungible-token crashpunks-v2 uint)

;; data structures

;; {owner, operator, nftIndex} -> boolean
;; if {owner, operator, nftIndex} is in map, then operator can perform actions on behalf of owner for this nftIndex
(define-map approvals {owner: principal, operator: principal, nft-index: uint} bool)

;; nftIndex -> {assetHash, metadataUrl}
(define-map nft-data uint {asset-hash: (buff 32), metadata-url: (string-ascii 256) })

;; nftIndex -> price (in ustx)
;; if nftIndex is not in map, it is not listed for sale
(define-map nft-market uint {price: uint})

;; SIP-09: get last token id
(define-read-only (get-last-token-id)
  (ok (- (var-get mint-counter) u1))
)

;; SIP-09: URI for metadata associated with the token
(define-read-only (get-token-uri (nftIndex uint))
  (ok (get metadata-url (map-get? nft-data nftIndex)))
)

;; SIP-09: Gets the owner of the 'Specified token ID.
(define-read-only (get-owner (nftIndex uint))
  (ok (nft-get-owner? crashpunks-v2 nftIndex))
)

;; SIP-09: Transfer
(define-public (transfer (nftIndex uint) (owner principal) (recipient principal))
    (begin
        ;; TODO: update these assertions
        ;; (asserts! (and (is-owner-or-approval id owner) (is-owner-or-approval id contract-caller)) (err ERR-NOT-AUTHORIZED))
        (asserts! (unwrap! (is-approved nftIndex contract-caller) ERR-NOT-AUTHORIZED) ERR-NOT-AUTHORIZED)
        (asserts! (is-none (map-get? nft-market nftIndex)) ERR-NFT-LISTED)
        (nft-transfer? crashpunks-v2 nftIndex owner recipient)
    )
)

;; operable-trait
(define-read-only (is-approved (nftIndex uint) (address principal))
    (let
        (
            (owner (unwrap! (nft-get-owner? crashpunks-v2 nftIndex) ERR-COULDNT-GET-NFT-OWNER))
        )
        (if (or
            (is-eq owner tx-sender)
            (is-eq owner contract-caller)
            (default-to false (map-get? approvals {owner: owner, operator: tx-sender, nft-index: nftIndex}))
            (default-to false (map-get? approvals {owner: owner, operator: contract-caller, nft-index: nftIndex}))
        ) 
            (ok true) 
            ERR-NOT-AUTHORIZED
        )
    )
)

;; operable-trait
(define-public (set-approved (nftIndex uint) (operator principal) (approved bool))
    (let
        (
            (owner (unwrap! (nft-get-owner? crashpunks-v2 nftIndex) ERR-NOT-OWNER))
        )
        (asserts! (is-eq owner contract-caller) ERR-NOT-OWNER)
        (if approved
            (ok (map-set approvals {owner: owner, operator: operator, nft-index: nftIndex} approved))
            (ok (map-delete approvals {owner: owner, operator: operator, nft-index: nftIndex}))
        )
    )

)
(define-public (burn (nftIndex uint))
    (let 
        (
            (owner (unwrap! (nft-get-owner? crashpunks-v2 nftIndex) ERR-NOT-OWNER))
        )
        (asserts! (is-eq owner contract-caller) ERR-NOT-OWNER)
        (map-delete nft-market nftIndex)
        (nft-burn? crashpunks-v2 nftIndex contract-caller)
    )
)

;; public methods

;; upgrade from v1 to v2
;; Owner of crashpunks v1 calls this upgrade function
;; 1. Transfers v1 NFT to this contract
;; 2. This contract mints the v2 NFT with the same nftIndex for contract-caller
;; 3. Copy the v1 data to v2
;; 4. This contract burns the v1 NFT
(define-public (upgrade-v1-to-v2 (nftIndex uint))
    ;; TODO: UPDATE V1 CONTRACT TO MAINNET CONTRACT
    (begin 
        ;; assert contract caller owns the v1 NFT at this nftIndex
        (asserts! (is-eq contract-caller (unwrap! (unwrap! (contract-call? .crashpunks-v1 get-owner nftIndex) (err u1001)) (err u1000))) ERR-NOT-V1-OWNER)

        ;; 1. transfer v1 NFT to this contract
        (try! (contract-call? .crashpunks-v1 transfer nftIndex contract-caller (as-contract tx-sender)))
        
        ;; 2. Mint the v2 NFT with the same nftIndex for contract-caller
        (try! (nft-mint? crashpunks-v2 nftIndex contract-caller))

        ;; 3. Copy v1 data to v2
        (try! (copy-data-from-v1 nftIndex))

        ;; 4. Burn the v1 NFT
        (try! (contract-call? .crashpunks-v1 burn nftIndex (as-contract tx-sender)))
        (ok nftIndex)
    )
)

(define-private (copy-data-from-v1 (nftIndex uint))
    (let (
        (v1-all-data (unwrap! (unwrap! (contract-call? .crashpunks-v1 get-token-by-index nftIndex) ERR-COULDNT-GET-V1-DATA) ERR-COULDNT-GET-V1-DATA))
        (v1-token-info (unwrap! (get tokenInfo v1-all-data) ERR-COULDNT-GET-V1-DATA))
        (asset-hash (get asset-hash v1-token-info))
        (metadata-url (get meta-data-url v1-token-info))
        )
        (ok (map-set nft-data
            nftIndex
            {asset-hash: asset-hash, metadata-url: metadata-url}
        ))
    )
)

(define-public (update-metadata-url (nftIndex uint) (newMetadataUrl (string-ascii 256)))
    (let
        (
            (data (unwrap! (map-get? nft-data nftIndex) ERR-NFT-DATA-NOT-FOUND))
        )
        ;; TODO: update these assertions
        ;; (asserts! (unwrap! (is-approved nftIndex (unwrap! (nft-get-owner? crashpunks nftIndex) not-allowed)) not-allowed) not-allowed)
        (ok (map-set nft-data
            nftIndex 
            (merge data
                {
                    metadata-url: newMetadataUrl
                }
            )
        ))
    )
)

(define-public (list-item (nftIndex uint) (amount uint))
    (begin 
        (asserts! (unwrap! (is-approved nftIndex contract-caller) ERR-NOT-AUTHORIZED) ERR-NOT-AUTHORIZED)
        (ok (map-set nft-market nftIndex {price: amount}))
    )
)

(define-public (unlist-item (nftIndex uint))
    (begin 
        (asserts! (unwrap! (is-approved nftIndex contract-caller) ERR-NOT-AUTHORIZED) ERR-NOT-AUTHORIZED)
        (ok (map-delete nft-market nftIndex))
    )
)

(define-public (buy-now (nftIndex uint))
    (let 
        (
            (ahash (unwrap! (get asset-hash (map-get? nft-data nftIndex)) ERR-ASSET-NOT-REGISTERED))
            (price (unwrap! (get price (map-get? nft-market nftIndex)) ERR-NFT-NOT-LISTED-FOR-SALE))
            (owner (unwrap! (unwrap! (get-owner nftIndex) ERR-COULDNT-GET-NFT-OWNER) ERR-COULDNT-GET-NFT-OWNER))
            (buyer contract-caller)
        )
        ;; (unwrap! (payment-split nftIndex amount tx-sender seriesOriginal) payment-error)
        (try! (payment-split nftIndex price contract-caller))
        (try! (nft-transfer? crashpunks-v2 nftIndex owner buyer))
        (map-delete nft-market nftIndex)
        (ok true)
    )
)

;; the contract administrator can change the contract administrator
(define-public (transfer-administrator (new-administrator principal))
    (begin
        (asserts! (is-eq (var-get administrator) contract-caller) ERR-NOT-ADMINISTRATOR)
        (ok (var-set administrator new-administrator))
    )
)

(define-public (set-collection-royalties (new-mint-addresses (list 4 principal)) (new-mint-shares (list 4 uint)) (new-royalty-addresses (list 10 principal)) (new-royalty-shares (list 10 uint)))
    (begin
        (asserts! (is-eq (var-get administrator) contract-caller) ERR-NOT-AUTHORIZED)
        (var-set collection-mint-addresses new-mint-addresses)
        (var-set collection-mint-shares new-mint-shares)
        (var-set collection-royalty-addresses new-royalty-addresses)
        (var-set collection-royalty-shares new-royalty-shares)
        (ok true)
    )
)

(define-read-only (get-token-data-by-index (nftIndex uint))
    (ok (map-get? nft-data nftIndex))
)

(define-read-only (get-token-market-by-index (nftIndex uint))
    (ok (map-get? nft-market nftIndex))
)

(define-private (payment-split (nftIndex uint) (saleAmount uint) (payer principal)) 
    (let 
        (
            (addresses (var-get collection-royalty-addresses))
            (shares (var-get collection-royalty-shares))
            (split u0)
        )
        (+ split (unwrap! (pay-royalty payer saleAmount (unwrap! (nft-get-owner? crashpunks-v2 nftIndex) ERR-PAYMENT-ADDRESS) (unwrap! (element-at shares u0) ERR-PAYMENT-ADDRESS)) ERR-PAYMENT-ADDRESS))
        (+ split (unwrap! (pay-royalty payer saleAmount (unwrap! (element-at addresses u1) ERR-PAYMENT-ADDRESS) (unwrap! (element-at shares u1) ERR-PAYMENT-ADDRESS)) ERR-PAYMENT-ADDRESS))
        (+ split (unwrap! (pay-royalty payer saleAmount (unwrap! (element-at addresses u2) ERR-PAYMENT-ADDRESS) (unwrap! (element-at shares u2) ERR-PAYMENT-ADDRESS)) ERR-PAYMENT-ADDRESS))
        (+ split (unwrap! (pay-royalty payer saleAmount (unwrap! (element-at addresses u3) ERR-PAYMENT-ADDRESS) (unwrap! (element-at shares u3) ERR-PAYMENT-ADDRESS)) ERR-PAYMENT-ADDRESS))
        (+ split (unwrap! (pay-royalty payer saleAmount (unwrap! (element-at addresses u4) ERR-PAYMENT-ADDRESS) (unwrap! (element-at shares u4) ERR-PAYMENT-ADDRESS)) ERR-PAYMENT-ADDRESS))
        (+ split (unwrap! (pay-royalty payer saleAmount (unwrap! (element-at addresses u5) ERR-PAYMENT-ADDRESS) (unwrap! (element-at shares u5) ERR-PAYMENT-ADDRESS)) ERR-PAYMENT-ADDRESS))
        (+ split (unwrap! (pay-royalty payer saleAmount (unwrap! (element-at addresses u6) ERR-PAYMENT-ADDRESS) (unwrap! (element-at shares u6) ERR-PAYMENT-ADDRESS)) ERR-PAYMENT-ADDRESS))
        (+ split (unwrap! (pay-royalty payer saleAmount (unwrap! (element-at addresses u7) ERR-PAYMENT-ADDRESS) (unwrap! (element-at shares u7) ERR-PAYMENT-ADDRESS)) ERR-PAYMENT-ADDRESS))
        (+ split (unwrap! (pay-royalty payer saleAmount (unwrap! (element-at addresses u8) ERR-PAYMENT-ADDRESS) (unwrap! (element-at shares u8) ERR-PAYMENT-ADDRESS)) ERR-PAYMENT-ADDRESS))
        (+ split (unwrap! (pay-royalty payer saleAmount (unwrap! (element-at addresses u9) ERR-PAYMENT-ADDRESS) (unwrap! (element-at shares u9) ERR-PAYMENT-ADDRESS)) ERR-PAYMENT-ADDRESS))
        ;; (print {evt: "payment-split", nftIndex: nftIndex, saleCycle: saleCycle, payer: payer, saleAmount: saleAmount, txSender: tx-sender})
        (ok split)
    )
)

(define-private (pay-royalty (payer principal) (saleAmount uint) (payee principal) (share uint))
    (if (> share u0)
        (let
            (
                (split (/ (* saleAmount share) percentage-with-twodp))
            )
            ;; ignore royalty payment if its to the buyer / tx-sender.
            (if (not (is-eq contract-caller payee))
                (try! (stx-transfer? split payer payee))
                true
            )
            ;; (print {evt: "pay-royalty-primary", payee: payee, payer: payer, saleAmount: saleAmount, share: share, split: split, txSender: tx-sender})
            (ok split)
        )
        (ok u0)
    )
)