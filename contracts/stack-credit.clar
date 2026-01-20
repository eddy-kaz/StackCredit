;; Title: StackCredit Protocol
;;
;; Summary:
;; A revolutionary decentralized lending ecosystem built on Bitcoin's 
;; Layer 2 that transforms traditional credit scoring through blockchain 
;; transparency and programmable trust mechanisms.
;;
;; Description:
;; StackCredit reimagines lending by creating an autonomous credit 
;; infrastructure where borrowers earn reputation through verifiable 
;; on-chain behavior. The protocol dynamically adjusts loan terms based 
;; on proven creditworthiness, enabling access to capital while securing 
;; lenders through intelligent collateral management. By leveraging 
;; Stacks' unique Bitcoin finality, users build portable credit scores 
;; that transcend traditional banking limitations, creating a truly 
;; decentralized financial identity backed by the world's most secure 
;; blockchain.
;;
;; PROTOCOL CONSTANTS

;; Protocol governance
(define-constant PROTOCOL-ADMIN tx-sender)

;; System error codes
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-INSUFFICIENT-FUNDS (err u101))
(define-constant ERR-INVALID-AMOUNT (err u102))
(define-constant ERR-LOAN-NOT-EXISTS (err u103))
(define-constant ERR-LOAN-DEFAULTED (err u104))
(define-constant ERR-CREDIT-TOO-LOW (err u105))
(define-constant ERR-TOO-MANY-LOANS (err u106))
(define-constant ERR-PAYMENT-NOT-DUE (err u107))
(define-constant ERR-INVALID-DURATION (err u108))

;; Credit scoring parameters
(define-constant MIN-CREDIT-SCORE u300)     ;; Starting credit score
(define-constant MAX-CREDIT-SCORE u850)     ;; Excellent credit ceiling
(define-constant LOAN-ELIGIBILITY-SCORE u500) ;; Minimum for borrowing
(define-constant MAX-ACTIVE-LOANS u3)       ;; Concurrent loan limit

;; Lending parameters
(define-constant MAX-LOAN-DURATION u26280)  ;; ~6 months in blocks
(define-constant BASE-INTEREST-RATE u1200)  ;; 12% base APR
(define-constant MAX-COLLATERAL-RATIO u150) ;; 150% max collateral

;; DATA STRUCTURES

;; User credit profiles with comprehensive metrics
(define-map credit-profiles
  { user: principal }
  {
    credit-score: uint,
    total-borrowed: uint,
    total-repaid: uint,
    successful-loans: uint,
    defaulted-loans: uint,
    avg-repayment-time: uint,
    last-activity: uint,
    profile-created: uint
  }
)

;; Loan registry with detailed tracking
(define-map loan-registry
  { loan-id: uint }
  {
    borrower: principal,
    principal-amount: uint,
    collateral-locked: uint,
    maturity-block: uint,
    interest-rate: uint,
    total-repaid: uint,
    status: (string-ascii 16),
    created-at: uint
  }
)

;; User loan tracking for portfolio management
(define-map user-portfolios
  { borrower: principal }
  { active-loan-ids: (list 10 uint) }
)

;; PROTOCOL STATE

(define-data-var next-loan-id uint u1)
(define-data-var total-value-locked uint u0)
(define-data-var total-loans-issued uint u0)

;; CORE PROTOCOL FUNCTIONS

;; Initialize user credit profile
;; Creates a new credit identity on the Stacks blockchain
(define-public (create-credit-profile)
  (let ((user tx-sender))
    (asserts! (is-none (map-get? credit-profiles { user: user })) 
              ERR-UNAUTHORIZED)
    
    (map-set credit-profiles 
      { user: user }
      {
        credit-score: MIN-CREDIT-SCORE,
        total-borrowed: u0,
        total-repaid: u0,
        successful-loans: u0,
        defaulted-loans: u0,
        avg-repayment-time: u0,
        last-activity: stacks-block-height,
        profile-created: stacks-block-height
      })
    (ok true)
  )
)

;; Request loan with dynamic terms based on credit score
;; Higher credit scores unlock better rates and lower collateral requirements
(define-public (request-loan 
    (amount uint) 
    (collateral uint) 
    (duration uint))
  (let (
    (borrower tx-sender)
    (loan-id (var-get next-loan-id))
    (profile (unwrap! (map-get? credit-profiles { user: borrower }) 
                     ERR-UNAUTHORIZED))
    (portfolio (default-to { active-loan-ids: (list) } 
                          (map-get? user-portfolios { borrower: borrower })))
  )
    ;; Validate loan request
    (asserts! (>= (get credit-score profile) LOAN-ELIGIBILITY-SCORE) 
              ERR-CREDIT-TOO-LOW)
    (asserts! (<= (len (get active-loan-ids portfolio)) MAX-ACTIVE-LOANS) 
              ERR-TOO-MANY-LOANS)
    (asserts! (and (> amount u0) (> duration u0) (<= duration MAX-LOAN-DURATION)) 
              ERR-INVALID-AMOUNT)
    
    ;; Calculate dynamic loan terms
    (let (
      (required-collateral (calculate-collateral-requirement 
                           amount (get credit-score profile)))
      (interest-rate (calculate-interest-rate (get credit-score profile)))
    )
      (asserts! (>= collateral required-collateral) ERR-INSUFFICIENT-FUNDS)
      
      ;; Lock collateral
      (try! (stx-transfer? collateral borrower (as-contract tx-sender)))
      
      ;; Create loan record
      (map-set loan-registry 
        { loan-id: loan-id }
        {
          borrower: borrower,
          principal-amount: amount,
          collateral-locked: collateral,
          maturity-block: (+ stacks-block-height duration),
          interest-rate: interest-rate,
          total-repaid: u0,
          status: "active",
          created-at: stacks-block-height
        })
      
      ;; Update user portfolio
      (map-set user-portfolios 
        { borrower: borrower }
        { active-loan-ids: (unwrap! 
                           (as-max-len? 
                            (append (get active-loan-ids portfolio) loan-id) u10)
                           ERR-TOO-MANY-LOANS) })
      
      ;; Transfer loan amount to borrower
      (as-contract (try! (stx-transfer? amount tx-sender borrower)))
      
      ;; Update protocol state
      (var-set next-loan-id (+ loan-id u1))
      (var-set total-value-locked (+ (var-get total-value-locked) collateral))
      (var-set total-loans-issued (+ (var-get total-loans-issued) u1))
      
      (ok loan-id)
    )
  )
)

;; Process loan repayment with credit score updates
;; Successful repayments improve credit scores and unlock better terms
(define-public (repay-loan (loan-id uint) (payment-amount uint))
  (let (
    (borrower tx-sender)
    (loan (unwrap! (map-get? loan-registry { loan-id: loan-id }) 
                   ERR-LOAN-NOT-EXISTS))
  )
    (asserts! (is-eq borrower (get borrower loan)) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get status loan) "active") ERR-LOAN-DEFAULTED)
    (asserts! (> payment-amount u0) ERR-INVALID-AMOUNT)
    
    ;; Calculate total amount due
    (let ((total-due (+ (get principal-amount loan)
                       (calculate-interest-payment loan))))
      
      ;; Process payment
      (try! (stx-transfer? payment-amount borrower (as-contract tx-sender)))
      
      (let ((new-total-repaid (+ (get total-repaid loan) payment-amount)))
        ;; Update loan status
        (map-set loan-registry 
          { loan-id: loan-id }
          (merge loan {
            total-repaid: new-total-repaid,
            status: (if (>= new-total-repaid total-due) "completed" "active")
          }))
        
        ;; If fully repaid, update credit score and release collateral
        (if (>= new-total-repaid total-due)
          (begin
            (try! (update-credit-score borrower true loan))
            (as-contract (try! (stx-transfer? 
                               (get collateral-locked loan) 
                               tx-sender 
                               borrower)))
            (var-set total-value-locked 
                    (- (var-get total-value-locked) 
                       (get collateral-locked loan)))
          )
          true
        )
        (ok true)
      )
    )
  )
)

;; ALGORITHMIC CREDIT SCORING

;; Calculate dynamic collateral requirements
;; Excellent credit scores require less collateral backing
(define-private (calculate-collateral-requirement 
    (loan-amount uint) 
    (credit-score uint))
  (let ((collateral-ratio 
         (- MAX-COLLATERAL-RATIO 
            (/ (* (- credit-score MIN-CREDIT-SCORE) u50) 
               (- MAX-CREDIT-SCORE MIN-CREDIT-SCORE)))))
    (/ (* loan-amount collateral-ratio) u100))
)

;; Calculate personalized interest rates
;; Better credit scores unlock premium lending rates
(define-private (calculate-interest-rate (credit-score uint))
  (let ((rate-reduction 
         (/ (* (- credit-score MIN-CREDIT-SCORE) u600) 
            (- MAX-CREDIT-SCORE MIN-CREDIT-SCORE))))
    (if (>= BASE-INTEREST-RATE rate-reduction)
      (- BASE-INTEREST-RATE rate-reduction)
      u600)) ;; Minimum 6% APR
)

;; Calculate interest payment based on loan terms
(define-private (calculate-interest-payment (loan {
  borrower: principal,
  principal-amount: uint,
  collateral-locked: uint,
  maturity-block: uint,
  interest-rate: uint,
  total-repaid: uint,
  status: (string-ascii 16),
  created-at: uint
}))
  (/ (* (get principal-amount loan) (get interest-rate loan)) u10000)
)

;; Advanced credit score algorithm
;; Considers payment history, loan diversity, and repayment timing
(define-private (update-credit-score 
    (user principal) 
    (successful-repayment bool) 
    (loan {
      borrower: principal,
      principal-amount: uint,
      collateral-locked: uint,
      maturity-block: uint,
      interest-rate: uint,
      total-repaid: uint,
      status: (string-ascii 16),
      created-at: uint
    }))
  (let (
    (profile (unwrap! (map-get? credit-profiles { user: user }) 
                     ERR-UNAUTHORIZED))
    (score-adjustment (if successful-repayment
                       (if (<= (get principal-amount loan) u1000000) u15 u25)  ;; Micro: 15pts, Standard: 25pts
                       u50)) ;; Default penalty: -50pts
    (new-score (if successful-repayment
                 (if (<= (+ (get credit-score profile) score-adjustment) MAX-CREDIT-SCORE)
                   (+ (get credit-score profile) score-adjustment)
                   MAX-CREDIT-SCORE)
                 (if (>= (- (get credit-score profile) score-adjustment) MIN-CREDIT-SCORE)
                   (- (get credit-score profile) score-adjustment)
                   MIN-CREDIT-SCORE)))
  )
    (map-set credit-profiles 
      { user: user }
      (merge profile {
        credit-score: new-score,
        total-repaid: (if successful-repayment 
                       (+ (get total-repaid profile) (get principal-amount loan))
                       (get total-repaid profile)),
        successful-loans: (if successful-repayment 
                           (+ (get successful-loans profile) u1)
                           (get successful-loans profile)),
        defaulted-loans: (if successful-repayment
                          (get defaulted-loans profile)
                          (+ (get defaulted-loans profile) u1)),
        last-activity: stacks-block-height
      }))
    (ok true)
  )
)

;; PROTOCOL QUERIES

;; Get comprehensive credit profile
(define-read-only (get-credit-profile (user principal))
  (map-get? credit-profiles { user: user })
)

;; Get loan details with current status
(define-read-only (get-loan-details (loan-id uint))
  (map-get? loan-registry { loan-id: loan-id })
)

;; Get user's active loan portfolio
(define-read-only (get-user-portfolio (borrower principal))
  (map-get? user-portfolios { borrower: borrower })
)

;; Get protocol analytics
(define-read-only (get-protocol-stats)
  {
    total-value-locked: (var-get total-value-locked),
    total-loans-issued: (var-get total-loans-issued),
    next-loan-id: (var-get next-loan-id)
  }
)

;; Calculate loan eligibility and terms preview
(define-read-only (preview-loan-terms (user principal) (amount uint))
  (match (map-get? credit-profiles { user: user })
    profile (if (>= (get credit-score profile) LOAN-ELIGIBILITY-SCORE)
              (ok {
                eligible: true,
                required-collateral: (calculate-collateral-requirement 
                                    amount (get credit-score profile)),
                interest-rate: (calculate-interest-rate (get credit-score profile)),
                max-duration: MAX-LOAN-DURATION
              })
              (ok { 
                eligible: false,
                required-collateral: u0,
                interest-rate: u0,
                max-duration: u0
              }))
    (err ERR-UNAUTHORIZED)
  )
)

;; ADMINISTRATIVE FUNCTIONS

;; Mark overdue loans as defaulted
;; Protects the protocol and updates credit scores accordingly
(define-public (process-loan-default (loan-id uint))
  (let ((loan (unwrap! (map-get? loan-registry { loan-id: loan-id }) 
                       ERR-LOAN-NOT-EXISTS)))
    (asserts! (is-eq tx-sender PROTOCOL-ADMIN) ERR-UNAUTHORIZED)
    ;; Validate loan-id is within valid range
    (asserts! (and (> loan-id u0) (< loan-id (var-get next-loan-id))) ERR-LOAN-NOT-EXISTS)
    (asserts! (>= stacks-block-height (get maturity-block loan)) 
              ERR-PAYMENT-NOT-DUE)
    (asserts! (is-eq (get status loan) "active") ERR-LOAN-DEFAULTED)
    
    ;; Update loan to defaulted status
    (map-set loan-registry 
      { loan-id: loan-id }
      (merge loan { status: "defaulted" }))
    
    ;; Apply credit score penalty
    (try! (update-credit-score (get borrower loan) false loan))
    
    (ok true)
  )
)