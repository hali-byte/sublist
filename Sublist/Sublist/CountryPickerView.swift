import SwiftUI

struct CountryPickerView: View {
    let initialCode: String
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private let countries: [(code: String, name: String)] = {
        Locale.Region.isoRegions
            .compactMap { region -> (String, String)? in
                guard let name = Locale.current.localizedString(forRegionCode: region.identifier) else { return nil }
                return (region.identifier, name)
            }
            .sorted { $0.1 < $1.1 }
    }()

    private var filtered: [(code: String, name: String)] {
        searchText.isEmpty ? countries :
            countries.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List(filtered, id: \.code) { country in
                Button {
                    onSelect(country.code)
                    dismiss()
                } label: {
                    HStack {
                        Text(country.name)
                        Spacer()
                        if country.code == initialCode {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.accent)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $searchText, prompt: "Search countries")
            .navigationTitle("Select Country")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
