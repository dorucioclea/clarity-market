;; A template used in Risidio Auctions to make is simple to onboard new DC projects.
(define-data-var owner principal 'params.contractOwner)
(define-data-var mint-price uint uparams.mintPrice)
(define-data-var base-token-uri (buff 100) params.callBack)
(define-map nongibles ((token-id (buff 32))) ((author principal) (date uint))) ;; extra info about token related to the nft-token
(define-non-fungible-token nongible-tokens (buff 32)) ;; identifier is 256-bit hash of image

;; ownable methods
(define-read-only (get-owner)
    (var-get owner))

(define-read-only (is-owner)
    (ok (is-eq (var-get owner) tx-sender)))

(define-read-only (only-owner)
    (if (is-eq (var-get owner) tx-sender) (ok none) (err 1)))

(define-public (transfer-ownership (new-owner principal))
    (begin 
        (asserts! (is-eq (var-get owner) tx-sender) (err 1))
        (var-set owner new-owner)
        (ok true)))

;; nongible methods
(define-public (update-base-token-uri (new-base-token-uri (buff 100)))
    (begin 
        (asserts! (is-eq (var-get owner) tx-sender) (err 1))
        (var-set base-token-uri new-base-token-uri)
        (ok true)))

(define-public (update-mint-price (new-mint-price uint))
    (begin 
        (asserts! (is-eq (var-get owner) tx-sender) (err 1))
        (var-set mint-price new-mint-price)
        (ok true)))

(define-read-only (get-base-token-uri)
    (var-get base-token-uri))

(define-read-only (get-mint-price)
    (var-get mint-price))

(define-read-only (get-token-uri (token-id (buff 32)))
    (concat (var-get base-token-uri) token-id))

(define-read-only (get-token-info (token-id (buff 32)))
    (map-get? nongibles ((token-id token-id))))

(define-public (create-nongible (token-id (buff 32)))
    (begin 
        (asserts! (>= (stx-get-balance tx-sender) (var-get mint-price)) (err 2))
        (as-contract
            (stx-transfer? (var-get mint-price) tx-sender (var-get owner))) ;; transfer stx if there is enough to pay for mint, otherwith throws an error
        (nft-mint? nongible-tokens token-id tx-sender) ;; fails if token has been minted before
        (map-insert nongibles ((token-id token-id)) ((author tx-sender) (date block-height)))
        (ok true)))