# Loota Mobile - TODO List

## Current Issues & Tasks

### High Priority
- [ ] **Real-time AR Updates**: When other players collect loot, the current player's AR view doesn't update to remove collected items until they restart the hunt
- [ ] **Hunt Completion Detection**: App should detect when hunt is completed and show completion screen without requiring app restart
- [ ] **Backend User Update Endpoint**: PUT `/api/users/{userId}` endpoint needs implementation for name updates

### Medium Priority
- [ ] **Error Handling**: Improve network error handling and user feedback for API failures
- [ ] **Location Accuracy**: Fine-tune GPS accuracy requirements for better AR object placement
- [ ] **Performance**: Optimize AR rendering for devices with limited resources
- [ ] **Sound Effects**: Add more audio feedback for different game actions

### Low Priority
- [ ] **Accessibility**: Improve VoiceOver support for AR elements
- [ ] **Localization**: Add support for multiple languages
- [ ] **Analytics**: Add usage tracking and crash reporting
- [ ] **Testing**: Expand unit test coverage

### Completed ✅
- [x] **Collected Loot Filtering**: Fixed app to only show uncollected loot in AR view
- [x] **Modal Pre-population**: Fixed hunt join modal to pre-populate with existing user data
- [x] **Data Model Updates**: Updated from `title` to `name` field and added participant phone extraction
- [x] **Compilation Errors**: Fixed all Swift compilation errors from data model changes

## Technical Debt
- [ ] **Code Comments**: Add comprehensive documentation to AR-related code
- [ ] **Refactoring**: Split large ContentView into smaller component views
- [ ] **Constants**: Move magic numbers to configuration constants
- [ ] **Dependency Injection**: Improve testability by reducing singleton usage

## Feature Requests
- [ ] **Hint System**: Add progressive hints for finding difficult-to-locate treasures
- [ ] **Social Features**: Allow players to see other active hunters on map
- [ ] **Hunt Creation**: Allow users to create their own treasure hunts
- [ ] **Leaderboards**: Add scoring and competitive elements

---

*Last updated: 2025-01-04*