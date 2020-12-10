;; Interface definitions
(impl-trait 'ST1ESYCGJB5Z5NBHS39XPC70PGC14WAQK5XXNQYDW.nft-interface.transferable-nft-trait)
(impl-trait 'ST1ESYCGJB5Z5NBHS39XPC70PGC14WAQK5XXNQYDW.nft-interface.tradable-nft-trait)

;; Non Fungible Token, modeled after ERC-721 via transferable-nft-trait
;; Note this is a basic implementation - no support yet for setting approvals for assets
;; NFT are identified by nft-index (uint) which is tied via a reverse lookup to a real world
;; asset hash - SHA 256 32 byte value. The Asset Hash is used to tie arbitrary real world
;; data to the NFT
(define-non-fungible-token my-nft uint)

;; data structures
(define-map my-nft-data ((nft-index uint)) ((asset-hash (buff 32)) (date uint)))
(define-map sale-data ((nft-index uint)) ((sale-type uint) (increment-stx uint) (reserve-stx uint) (amount-stx uint) (bidding-end-time uint)))
(define-map my-nft-lookup ((asset-hash (buff 32))) ((nft-index uint)))
(define-map transfer-map ((nft-index uint)) ((transfer-count uint)))
(define-map transfer-history-map ((nft-index uint) (transfer-count uint)) ((from principal) (to principal) (sale-type uint) (when uint) (amount uint)))

;; variables
(define-data-var administrator principal 'STGPPTWJEZ2YAA7XMPVZ7EGKH0WX9F2DBNHTG5EY)
(define-data-var mint-price uint u10000)
(define-data-var base-token-uri (buff 100) 0x68747470733a2f2f6c6f6f70626f6d622e7269736964696f2e636f6d2f696e6465782f76312f61737365742f)
(define-data-var mint-counter uint u0)
(define-data-var platform-fee uint u5)

;; constants
(define-constant token-name "loopbomb")
(define-constant token-symbol "LOOP")

(define-constant not-allowed (err u10))
(define-constant not-found (err u11))
(define-constant amount-not-set (err u12))
(define-constant seller-not-found (err u13))
(define-constant asset-not-registered (err u14))
(define-constant transfer-error (err u15))
(define-constant not-approved-to-sell (err u16))

(define-constant same-spender-err (err u1))
(define-constant failed-to-mint-err (err u5))

;;(define-constant not-approved-spender-err (err u2))
;;(define-constant failed-to-move-token-err (err u3))
;;(define-constant unauthorized-transfer-err (err u4))

;; public methods
;; --------------
(define-public (transfer-administrator (new-administrator principal))
    (begin
        (asserts! (is-eq (var-get administrator) tx-sender) not-allowed)
        (var-set administrator new-administrator)
        (ok true)
    )
)

(define-public (change-fee (new-fee uint))
    (begin
        (asserts! (is-eq (var-get administrator) tx-sender) not-allowed)
        (var-set platform-fee new-fee)
        (ok true)
    )
)

(define-public (update-base-token-uri (new-base-token-uri (buff 100)))
    (begin 
        (asserts! (is-eq (var-get administrator) tx-sender) not-allowed)
        (var-set base-token-uri new-base-token-uri)
        (ok true)
    )
)

(define-public (update-mint-price (new-mint-price uint))
    (begin 
        (asserts! (is-eq (var-get administrator) tx-sender) not-allowed)
        (var-set mint-price new-mint-price)
        (ok true)
    )
)

(define-public (mint-token (asset-hash (buff 32)))
    (begin
        (asserts! (> (stx-get-balance tx-sender) (var-get mint-price)) failed-to-mint-err)
        (as-contract
            (stx-transfer? (var-get mint-price) tx-sender (var-get administrator))) ;; transfer stx if there is enough to pay for mint, otherwith throws an error
        (nft-mint? my-nft (var-get mint-counter) tx-sender)
        (map-insert my-nft-data ((nft-index (var-get mint-counter))) ((asset-hash asset-hash) (date block-height)))
        (map-insert my-nft-lookup ((asset-hash asset-hash)) ((nft-index (var-get mint-counter))))
        (var-set mint-counter (+ (var-get mint-counter) u1))
        (ok (var-get mint-counter))
    )
)

;; set-sale-data updates the sale type and purchase info for a given NFT. Only the owner can call this method
;; and doing so make the asset transferable by the recipient - on condition of meeting the conditions of sale
;; This is equivalent to the setApprovalForAll method in ERC 721 contracts.
(define-public (set-sale-data (asset-hash (buff 32)) (sale-type uint) (increment-stx uint) (reserve-stx uint) (amount-stx uint) (bidding-end-time uint))
    (let
        (
            (myIndex (unwrap! (get nft-index (map-get? my-nft-lookup ((asset-hash asset-hash)))) not-found))
        )
        (if
            (is-ok (is-nft-owner myIndex))
            (if (map-set sale-data {nft-index: myIndex} ((sale-type sale-type) (increment-stx increment-stx) (reserve-stx reserve-stx) (amount-stx amount-stx) (bidding-end-time bidding-end-time)))
                (ok myIndex) not-allowed
            )
            not-allowed
        )
    )
)

;; transfer - differs from blockstack nft contract in that the tx-sender is the recipient
;; of the asset rather than the owner.
;; tx-sender / buyer transfers 'platform-fee'% of the buy now amount to the 
;; contract miner-address remainder to the seller address. Reset the 
;; map data in sale-data and my-nft data to indicate not for sale and BNS 
;; name of new owner.
(define-public (transfer-from (seller principal) (buyer principal) (nft-index uint))
    (let 
        (
            (saleType (get sale-type (map-get? sale-data {nft-index: nft-index})))
            (amount (get amount-stx (map-get? sale-data {nft-index: nft-index})))
            (seller1 (nft-get-owner? my-nft nft-index))
            (ahash (get asset-hash (map-get? my-nft-data {nft-index: nft-index})))
        )
        (asserts! (is-some ahash) asset-not-registered)
        (asserts! (is-eq (unwrap! saleType seller-not-found) u1) not-approved-to-sell)
        (asserts! (> (unwrap! amount amount-not-set) u0) amount-not-set)
        (asserts! (is-eq buyer tx-sender) same-spender-err)
        (asserts! (not (is-eq (unwrap! seller1 seller-not-found) seller)) seller-not-found)
        (let ((count (inc-transfer-count nft-index)))
            (add-transfer nft-index (- count u1) seller buyer (unwrap! saleType seller-not-found) u0 (unwrap! amount amount-not-set))
        )
        (map-set my-nft-data { nft-index: nft-index } { asset-hash: (unwrap! ahash not-found), date: block-height })
        (map-set sale-data { nft-index: nft-index } { amount-stx: u0, bidding-end-time: u0, increment-stx: u0, reserve-stx: u0, sale-type: u0 })
        (stx-transfer? (/ (* (unwrap! amount amount-not-set) (var-get platform-fee)) u100) tx-sender (as-contract tx-sender))
        (stx-transfer? (/ (* (unwrap! amount amount-not-set) (- u100 (var-get platform-fee))) u100) tx-sender (unwrap! seller1 seller-not-found))
        (if 
            (is-ok (nft-transfer? my-nft nft-index (unwrap! seller1 seller-not-found) tx-sender))
            (ok u0) transfer-error
        )
    )
)

;; Transfers tokens to a specified principal.
(define-public (transfer (seller principal) (nft-index uint))
    (if (is-ok (transfer-from seller tx-sender nft-index))
        (ok u0) (err u1)
    )
)

;; not yet implemented
(define-public (balance-of (recipient principal))
  (if (is-eq tx-sender recipient)
      (ok u0)
      (err u1)
  )
)

;; read only methods
;; ---------------
(define-read-only (get-administrator)
    (var-get administrator))

(define-read-only (is-administrator)
    (ok (is-eq (var-get administrator) tx-sender)))

(define-read-only (get-base-token-uri)
    (var-get base-token-uri))

(define-read-only (get-mint-counter)
  (ok (var-get mint-counter))
)

(define-read-only (get-mint-price)
    (var-get mint-price))

(define-read-only (get-token-info (nft-index uint))
    (map-get? my-nft-data ((nft-index nft-index)))
)

(define-read-only (get-token-info-full (nft-index uint))
    (let 
        (
            (the-token-info (map-get? my-nft-data ((nft-index nft-index))))
            (the-sale-data (map-get? sale-data ((nft-index nft-index))))
            (the-owner (unwrap-panic (nft-get-owner? my-nft nft-index)))
            (the-tx-count (default-to u0 (get transfer-count (map-get? transfer-map (tuple (nft-index nft-index))))))
        )
        (ok (tuple (token-info the-token-info) (sale-data the-sale-data) (owner the-owner) (transfer-count the-tx-count)))
    )
)

(define-read-only (get-index (asset-hash (buff 32)))
    (match (map-get? my-nft-lookup ((asset-hash asset-hash)))
        myIndex
        (ok (get nft-index myIndex))
        not-found
    )
)

(define-read-only (get-sale-data (nft-index uint))
    (match (map-get? sale-data ((nft-index nft-index)))
        mySaleData
        (ok mySaleData)
        not-found
    )
)

(define-read-only (get-transfer-count (nft-index uint))
    (let 
        (
            (count (default-to u0 (get transfer-count (map-get? transfer-map (tuple (nft-index nft-index))))))
        )
        (ok count)
    )
)

(define-read-only (get-token-name)
    (ok token-name)
)

(define-read-only (get-token-symbol)
    (ok token-symbol)
)

;; private methods
;; ---------------
(define-private (is-nft-owner (nft-index uint))
    (if (is-eq (some tx-sender) (nft-get-owner? my-nft nft-index))
        (ok true)
        not-allowed
    )
)
(define-private (inc-transfer-count (nft-index uint))
    (let 
        (
            (count (default-to u0 (get transfer-count (map-get? transfer-map (tuple (nft-index nft-index))))))
        )
        (begin 
            (map-insert transfer-map { nft-index: nft-index } { transfer-count: count})
            (+ count u1)
        )
    )
)

(define-private (add-transfer (nft-index uint) (transfer-count uint) (from principal) (to principal) (sale-type uint) (when uint) (amount uint))
  (if (is-eq to tx-sender)
    (ok (map-insert transfer-history-map {nft-index: nft-index, transfer-count: transfer-count} ((from from) (to to) (sale-type sale-type) (when when) (amount amount))))
    not-allowed
  )
)