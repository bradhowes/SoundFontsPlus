// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import HostSupport
import Sharing
import SwiftUI

@Reducer
public struct Settings {

  @ObservableState
  public struct State: Equatable {
    public var componentSubtype: String
    public var componentManufacturer: String
    public var colorSchemeBehavior: ColorSchemeBehavior

    public init() {
      @Shared(.componentSubtype) var componentSubtype
      @Shared(.componentManufacturer) var componentManufacturer
      @Shared(.colorSchemeBehavior) var colorSchemeBehavior
      self.componentSubtype = componentSubtype
      self.componentManufacturer = componentManufacturer
      self.colorSchemeBehavior = colorSchemeBehavior
    }
  }

  @CasePathable
  public enum Action: BindableAction {
    case binding(BindingAction<State>)
    case delegate(Delegate)
    case cancelButtonTapped
    case acceptButtonTapped

    @CasePathable
    public enum Delegate {
      case accepted
      case cancelled
      case configurationChanged
    }
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    BindingReducer()

    Reduce { state, action in
      switch action {

      case .acceptButtonTapped:
        return accepted(&state)

      case .cancelButtonTapped:
        return cancelled(&state)

      case .delegate:
        return .none

      default:
        return .none
      }
    }
  }
}

extension Settings {

  private func accepted(_ state: inout State) -> Effect<Action> {
    @Shared(.componentSubtype) var componentSubtype
    @Shared(.componentManufacturer) var componentManufacturer
    @Shared(.colorSchemeBehavior) var colorSchemeBehavior

    $colorSchemeBehavior.withLock { $0 = state.colorSchemeBehavior }
    let action: Action
    if state.componentSubtype != componentSubtype || state.componentManufacturer != componentManufacturer {
      $componentSubtype.withLock { $0 = state.componentSubtype }
      $componentManufacturer.withLock { $0 = state.componentManufacturer }
      action = .delegate(.configurationChanged)
    } else {
      action = .delegate(.accepted)
    }
    return .run { send in
      @Dependency(\.dismiss) var dismiss
      await send(action)
      await dismiss()
    }
  }

  private func cancelled(_ state: inout State) -> Effect<Action> {
    return .run { send in
      @Dependency(\.dismiss) var dismiss
      await send(.delegate(.cancelled))
      await dismiss()
    }
  }
}

extension Settings.Action: Sendable {}
extension Settings.Action.Delegate: Sendable {}

public struct SettingsView: View {
  @Bindable private var store: StoreOf<Settings>
  @State private var subtypeIssue: String = ""
  @State private var manufacturerIssue: String = ""

  public init(store: StoreOf<Settings>) {
    self.store = store
  }

  public var body: some View {
    NavigationStack {
      Form {
        HStack(spacing: 16) {
          Text("Subtype:")
          TextField("", text: $store.componentSubtype)
            .textFieldStyle(.roundedBorder)
#if os(iOS)
            .autocapitalization(.none)
#endif
            .autocorrectionDisabled()
            .frame(maxWidth: 80)
            .onChange(of: store.componentSubtype) {
              subtypeIssue = validateField(&store.componentSubtype)
            }
          Text(subtypeIssue)
            .foregroundStyle(.red)
        }
        HStack(spacing: 16) {
          Text("Manufacturer:")
          TextField("", text: $store.componentManufacturer, onEditingChanged: { _ in
          })
          .textFieldStyle(.roundedBorder)
#if os(iOS)
          .autocapitalization(.none)
#endif
          .autocorrectionDisabled()
          .frame(maxWidth: 80)
          .onChange(of: store.componentManufacturer) {
            manufacturerIssue = validateField(&store.componentManufacturer)
          }
          Text(manufacturerIssue)
            .foregroundStyle(.red)
        }
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text("Color scheme")
            Spacer()
            Picker(
              selection: $store.colorSchemeBehavior
            ) {
              ForEach(ColorSchemeBehavior.allCases) { kind in
                Text(kind.rawValue)
              }
            } label: {
              Text("")
            }
            .pickerStyle(.segmented)
          }
          Text(
"""
The color scheme can track the device's setting, or it can be fixed to a constant scheme.
"""
          )
          .font(.footnote)
        }
        .navigationTitle("Settings")
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
              store.send(.cancelButtonTapped, animation: .default)
            }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button("Accept") {
              store.send(.acceptButtonTapped, animation: .default)
            }
          }
        }
      }
    }
    .useColorScheme() // TODO: find better approach for updating colorScheme when colorSchemeBehavior changes
  }

  private func validateField(_ value: inout String) -> String {
    if value.isEmpty {
      return "Empty value"
    } else if value.count < 4 {
      return "Must be 4 characters"
    } else if !store.componentSubtype.allSatisfy({ $0.isPrintableASCII }) {
      return "Must contain ASCII characters"
    } else if value.count > 4 {
      value = String(value.prefix(4))
    }
    return ""
  }
}

extension SettingsView {
  static var preview: some View {
    return SettingsView(store: Store(initialState: .init()) { Settings() })
  }
}

#Preview {
  SettingsView.preview
}
