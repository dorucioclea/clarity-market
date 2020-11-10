;; data structures
;; ---------------
(define-non-fungible-token params.token uint)
(define-map params.token-data ((index uint)) ((owner (buff 80)) (asset-hash (buff 32)) (date uint)))
(define-map params.token-lookup ((asset-hash (buff 32))) ((index uint)))

(define-data-var administrator principal 'params.contractOwner)
(define-data-var mint-price uint uparams.mintPrice)
(define-data-var base-token-uri (buff 100) params.callBack)
(define-data-var mint-counter uint u0) ;; tracks nft creation

;; public methods
;; --------------
(define-public (transfer-administrator (new-administrator principal))
    (begin
        (asserts! (is-eq (var-get administrator) tx-sender) (err 1))
        (var-set administrator new-administrator)
        (ok true)))

(define-public (update-base-token-uri (new-base-token-uri (buff 100)))
    (begin
        (asserts! (is-eq (var-get administrator) tx-sender) (err 1))
        (var-set base-token-uri new-base-token-uri)
        (ok true)))

(define-public (update-mint-price (new-mint-price uint))
    (begin
        (asserts! (is-eq (var-get administrator) tx-sender) (err 1))
        (var-set mint-price new-mint-price)
        (ok true)))

(define-public (mint-token (asset-hash (buff 32)) (owner (buff 80)))
    (begin
        (asserts! (> (stx-get-balance tx-sender) (var-get mint-price)) (err 2))
        (as-contract
            (stx-transfer? (var-get mint-price) tx-sender (var-get administrator))) ;; transfer stx if there is enough to pay for mint, otherwith throws an error
        (nft-mint? params.token (var-get mint-counter) tx-sender)
        (map-insert params.token-data ((index (var-get mint-counter))) ((owner owner) (asset-hash asset-hash) (date block-height)))
        (map-insert params.token-lookup ((asset-hash asset-hash)) ((index (var-get mint-counter))))
        (var-set mint-counter (+ (var-get mint-counter) u1))
        (ok (var-get mint-counter))))

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

(define-read-only (get-token-info (index uint))
    (map-get? params.token-data ((index index))))

(define-read-only (get-index (asset-hash (buff 32)))
    (map-get? params.token-lookup ((asset-hash asset-hash))))

;; private methods
;; ---------------
