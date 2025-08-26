;; Community Benefits Contract
;; Manages revenue sharing and cultural preservation funding

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-COMMUNITY-NOT-FOUND (err u401))
(define-constant ERR-INVALID-AMOUNT (err u402))
(define-constant ERR-INSUFFICIENT-FUNDS (err u403))
(define-constant ERR-INVALID-PERCENTAGE (err u404))

;; Data Variables
(define-data-var next-community-id uint u1)
(define-data-var next-project-id uint u1)
(define-data-var total-community-fund uint u0)

;; Data Maps
(define-map communities
  { community-id: uint }
  {
    community-name: (string-ascii 100),
    location: (string-ascii 50),
    representative: principal,
    total-revenue-received: uint,
    total-preservation-funding: uint,
    active-projects: uint,
    community-score: uint,
    is-verified: bool,
    created-at: uint
  }
)

(define-map community-by-location
  { location: (string-ascii 50) }
  { community-id: uint }
)

(define-map revenue-distributions
  { community-id: uint, experience-id: uint }
  {
    total-revenue: uint,
    community-share: uint,
    guide-share: uint,
    platform-share: uint,
    distribution-date: uint,
    distribution-status: (string-ascii 20)
  }
)

(define-map preservation-projects
  { project-id: uint }
  {
    community-id: uint,
    project-name: (string-ascii 100),
    description: (string-ascii 500),
    funding-goal: uint,
    current-funding: uint,
    project-status: (string-ascii 20),
    impact-metrics: (list 5 (string-ascii 50)),
    created-by: principal,
    created-at: uint
  }
)

(define-map impact-reports
  { community-id: uint, report-period: uint }
  {
    economic-impact: uint,
    cultural-preservation-score: uint,
    community-engagement: uint,
    sustainability-metrics: uint,
    beneficiaries-count: uint,
    report-date: uint
  }
)

;; Public Functions

;; Register a community
(define-public (register-community (community-name (string-ascii 100)) (location (string-ascii 50)))
  (let
    (
      (community-id (var-get next-community-id))
      (existing-community (map-get? community-by-location { location: location }))
    )
    (asserts! (is-none existing-community) ERR-COMMUNITY-NOT-FOUND)

    (map-set communities
      { community-id: community-id }
      {
        community-name: community-name,
        location: location,
        representative: tx-sender,
        total-revenue-received: u0,
        total-preservation-funding: u0,
        active-projects: u0,
        community-score: u0,
        is-verified: false,
        created-at: block-height
      }
    )

    (map-set community-by-location
      { location: location }
      { community-id: community-id }
    )

    (var-set next-community-id (+ community-id u1))
    (ok community-id)
  )
)

;; Distribute revenue to community
(define-public (distribute-revenue
  (community-id uint)
  (experience-id uint)
  (total-revenue uint)
  (community-percentage uint))
  (let
    (
      (community-data (unwrap! (map-get? communities { community-id: community-id }) ERR-COMMUNITY-NOT-FOUND))
      (community-share (/ (* total-revenue community-percentage) u100))
      (guide-share (/ (* total-revenue u60) u100))
      (platform-share (- total-revenue (+ community-share guide-share)))
    )
    (asserts! (> total-revenue u0) ERR-INVALID-AMOUNT)
    (asserts! (and (>= community-percentage u10) (<= community-percentage u50)) ERR-INVALID-PERCENTAGE)

    (map-set revenue-distributions
      { community-id: community-id, experience-id: experience-id }
      {
        total-revenue: total-revenue,
        community-share: community-share,
        guide-share: guide-share,
        platform-share: platform-share,
        distribution-date: block-height,
        distribution-status: "completed"
      }
    )

    (map-set communities
      { community-id: community-id }
      (merge community-data { total-revenue-received: (+ (get total-revenue-received community-data) community-share) })
    )

    (var-set total-community-fund (+ (var-get total-community-fund) community-share))
    (ok community-share)
  )
)

;; Create preservation project
(define-public (create-preservation-project
  (community-id uint)
  (project-name (string-ascii 100))
  (description (string-ascii 500))
  (funding-goal uint)
  (impact-metrics (list 5 (string-ascii 50))))
  (let
    (
      (community-data (unwrap! (map-get? communities { community-id: community-id }) ERR-COMMUNITY-NOT-FOUND))
      (project-id (var-get next-project-id))
    )
    (asserts! (> funding-goal u0) ERR-INVALID-AMOUNT)
    (asserts! (or (is-eq tx-sender (get representative community-data)) (is-eq tx-sender CONTRACT-OWNER)) ERR-NOT-AUTHORIZED)

    (map-set preservation-projects
      { project-id: project-id }
      {
        community-id: community-id,
        project-name: project-name,
        description: description,
        funding-goal: funding-goal,
        current-funding: u0,
        project-status: "active",
        impact-metrics: impact-metrics,
        created-by: tx-sender,
        created-at: block-height
      }
    )

    (map-set communities
      { community-id: community-id }
      (merge community-data { active-projects: (+ (get active-projects community-data) u1) })
    )

    (var-set next-project-id (+ project-id u1))
    (ok project-id)
  )
)

;; Fund preservation project
(define-public (fund-preservation-project (project-id uint) (funding-amount uint))
  (let
    (
      (project-data (unwrap! (map-get? preservation-projects { project-id: project-id }) ERR-COMMUNITY-NOT-FOUND))
      (community-data (unwrap! (map-get? communities { community-id: (get community-id project-data) }) ERR-COMMUNITY-NOT-FOUND))
      (new-funding (+ (get current-funding project-data) funding-amount))
    )
    (asserts! (> funding-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (<= new-funding (get funding-goal project-data)) ERR-INVALID-AMOUNT)

    (map-set preservation-projects
      { project-id: project-id }
      (merge project-data { current-funding: new-funding })
    )

    (map-set communities
      { community-id: (get community-id project-data) }
      (merge community-data { total-preservation-funding: (+ (get total-preservation-funding community-data) funding-amount) })
    )

    (ok new-funding)
  )
)

;; Submit impact report
(define-public (submit-impact-report
  (community-id uint)
  (report-period uint)
  (economic-impact uint)
  (cultural-preservation-score uint)
  (community-engagement uint)
  (sustainability-metrics uint)
  (beneficiaries-count uint))
  (let
    (
      (community-data (unwrap! (map-get? communities { community-id: community-id }) ERR-COMMUNITY-NOT-FOUND))
    )
    (asserts! (or (is-eq tx-sender (get representative community-data)) (is-eq tx-sender CONTRACT-OWNER)) ERR-NOT-AUTHORIZED)

    (map-set impact-reports
      { community-id: community-id, report-period: report-period }
      {
        economic-impact: economic-impact,
        cultural-preservation-score: cultural-preservation-score,
        community-engagement: community-engagement,
        sustainability-metrics: sustainability-metrics,
        beneficiaries-count: beneficiaries-count,
        report-date: block-height
      }
    )

    (try! (update-community-score community-id cultural-preservation-score))
    (ok true)
  )
)

;; Private Functions

;; Update community score based on impact
(define-private (update-community-score (community-id uint) (preservation-score uint))
  (let
    (
      (community-data (unwrap! (map-get? communities { community-id: community-id }) ERR-COMMUNITY-NOT-FOUND))
    )
    (map-set communities
      { community-id: community-id }
      (merge community-data { community-score: preservation-score })
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get community information
(define-read-only (get-community (community-id uint))
  (map-get? communities { community-id: community-id })
)

;; Get community by location
(define-read-only (get-community-by-location (location (string-ascii 50)))
  (match (map-get? community-by-location { location: location })
    community-ref (map-get? communities { community-id: (get community-id community-ref) })
    none
  )
)

;; Get revenue distribution
(define-read-only (get-revenue-distribution (community-id uint) (experience-id uint))
  (map-get? revenue-distributions { community-id: community-id, experience-id: experience-id })
)

;; Get preservation project
(define-read-only (get-preservation-project (project-id uint))
  (map-get? preservation-projects { project-id: project-id })
)

;; Get impact report
(define-read-only (get-impact-report (community-id uint) (report-period uint))
  (map-get? impact-reports { community-id: community-id, report-period: report-period })
)

;; Get total community fund
(define-read-only (get-total-community-fund)
  (var-get total-community-fund)
)

;; Get next community ID
(define-read-only (get-next-community-id)
  (var-get next-community-id)
)

;; Get next project ID
(define-read-only (get-next-project-id)
  (var-get next-project-id)
)
