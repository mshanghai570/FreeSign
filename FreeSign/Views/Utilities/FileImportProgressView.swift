//
//  FileImportProgressView.swift
//  FreeSign
//
//  Created by Michael Shingara on 7/30/26.
//

import SwiftUI

struct FileImportProgressView: View {
    @StateObject private var fileImporter = FileImporter.shared
    @Environment(\.dismiss) private var dismiss
    
    let url: URL
    
    var body: some View {
        VStack(spacing: 20) {
            // Progress / result indicator
            if fileImporter.isImporting {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent))
                    .scaleEffect(1.5)
            } else if let error = fileImporter.lastImportError {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(AppColors.destructive)
                Text(error)
                    .font(AppFont.body)
                    .foregroundColor(AppColors.destructive)
                    .multilineTextAlignment(.center)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(AppColors.success)
            }
            
            // Progress text
            Text(fileImporter.importProgress)
                .font(AppFont.title)
                .foregroundColor(AppColors.primaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            // File info
            VStack(spacing: 8) {
                Text(url.lastPathComponent)
                    .font(AppFont.body)
                    .foregroundColor(AppColors.secondaryText)
                    .lineLimit(2)
                
                if let fileType = FileImporter.detectFileType(from: url) {
                    Text(fileType.name)
                        .font(AppFont.caption)
                        .foregroundColor(AppColors.disabledText)
                }
            }
            .padding(.top, 10)
            
            if !fileImporter.isImporting {
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.accent)
            }
            
            Spacer()
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.surface)
        .appNavigationTitle("Importing File")
        .onChange(of: fileImporter.isImporting) { isImporting in
            // Auto-dismiss only on success so errors stay visible
            if !isImporting && fileImporter.lastImportError == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    FileImportProgressView(url: URL(fileURLWithPath: "/path/to/test.ipa"))
        .environmentObject(FileImporter.shared)
}