# RecruiterMatch

An iPhone app for recruiters: create a candidate profile, upload their CV, and get the
top 10 companies to target for that person — matched on skills, title, and CV content.
All candidate data (including the CV file itself) is stored in **CloudKit** (the
recruiter's private iCloud database), so it backs up automatically and syncs across
their own devices.

This was built in a Linux container without Xcode/macOS available, so it has **not been
compiled or run**. It's a complete, from-scratch SwiftUI source tree — you'll need a Mac
with Xcode 15+ to build, fix any small issues that come up on first compile, and ship it.

## What's here

```
RecruiterMatch/
  project.yml                  XcodeGen project definition (source of truth — .xcodeproj is generated, not committed)
  RecruiterMatch/
    RecruiterMatchApp.swift     App entry point
    Info.plist
    RecruiterMatch.entitlements CloudKit capability
    Models/
      Candidate.swift           Candidate profile + CloudKit CKRecord mapping
      Company.swift              Company reference data model
      MatchResult.swift
    Services/
      CloudKitManager.swift     Private-database CRUD, account status
      CandidateStore.swift      App-level ObservableObject store
      CVTextExtractor.swift     PDF/text/RTF text extraction (PDFKit)
      MatchingEngine.swift      Weighted keyword matching / scoring
      Keywords.swift            Tokenizer, stopwords, synonym table
    Resources/
      Companies.json            63 bundled example companies across many industries
    Views/
      CandidateListView.swift
      CandidateFormView.swift
      CandidateDetailView.swift
      MatchResultsView.swift
      CompanyDetailView.swift
      Components/
        SkillChipView.swift     Skill chip + wrapping layout
        ScoreBadge.swift        Circular match-score indicator
    Assets.xcassets/
```

## How matching works

There's no external "which companies are hiring" API wired up (that would need a paid
job-board data feed, e.g. LinkedIn, Indeed, or a data provider like Coresignal/People
Data Labs). Instead, `Resources/Companies.json` is a bundled reference dataset — 63
**fictional example companies** spanning tech, finance, healthcare, biotech, manufacturing,
retail, media, energy, defense, nonprofit, and more, each tagged with the skills, roles,
and hiring keywords typical of that kind of company.

`MatchingEngine.swift` builds a weighted keyword "bag" for the candidate (explicit skills
count most, then title, then CV text, then notes) and for each company (tags count most,
then common roles, then softer culture/keyword signals), scores them with a weighted
cosine similarity plus a small title/role-affinity bonus, and returns the top 10. This
all runs on-device — nothing about the candidate or their CV is sent anywhere.

**To make this useful for real recruiting**, replace `Companies.json` with your actual
target company list (e.g. exported from your ATS/CRM or a real firmographic data
provider) using the same schema — `id, name, industry, subIndustries, size, hqLocation,
description, tags, commonRoles, hiringKeywords`. The matching code needs no changes.

## CV parsing

- **PDF** — full text extraction via PDFKit.
- **.txt / .rtf** — direct text extraction.
- **.docx / .doc / .pages** — the file is still uploaded and stored with the profile, but
  automatic text extraction isn't implemented (would need a zip/XML parser or a
  dependency like ZIPFoundation). The form shows a notice and the recruiter can add key
  skills manually so matching still works well.
- A scanned/image-only PDF also can't be text-extracted; same fallback applies.

## Before you build

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
2. From this directory, run:
   ```
   xcodegen generate
   open RecruiterMatch.xcodeproj
   ```
3. In Xcode, select the `RecruiterMatch` target → **Signing & Capabilities**:
   - Set your Apple Developer **Team**.
   - Change the bundle identifier from `com.recruitermatch.app` to something under your
     own team (also update it in `project.yml` and in `RecruiterMatch.entitlements`,
     where the iCloud container is `iCloud.com.recruitermatch.app`).
   - Confirm the **iCloud** capability is enabled with the **CloudKit** service checked,
     and that it's using the container id from the entitlements file (Xcode may ask to
     create the container in your account the first time).
4. Build to a real device or the simulator, signed in with an iCloud account (Settings →
   [your name]). CloudKit's private database requires a signed-in iCloud account — the
   app detects and surfaces this via a banner if it isn't.
5. First run: the `Candidate` record type is created in your CloudKit container
   automatically the first time you save a candidate, in development mode. Before
   shipping, open the [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard/),
   confirm the `Candidate` schema (indexes on `updatedAt` for sorting, `queryable` on the
   fields you search), and **deploy the schema to Production**.
6. Add a real 1024×1024 app icon to `Assets.xcassets/AppIcon.appiconset` (an empty
   placeholder is checked in) before submitting to the App Store.

## Known gaps / next steps

- No authentication beyond the device's iCloud account — by design, since this is a
  single recruiter's private data store, not a shared team database. Sharing candidates
  with a team would mean moving to `CKShare` / the shared database, which is a bigger
  change.
- No push-based sync notifications (`CKQuerySubscription`) — the list refreshes on
  launch and pull-to-refresh. Add subscriptions + a `CKSyncEngine`/`NSPersistentCloudKitContainer`
  layer if you want live multi-device updates.
- `.docx` text extraction is a stub (see above).
- No automated tests yet.
