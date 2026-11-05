#!/usr/bin/env ruby
# Generates Pourtrait.xcodeproj without needing a Mac or XcodeGen.
#
#   gem install xcodeproj
#   ruby scripts/generate_xcodeproj.rb
#
# Mirrors project.yml. On a Mac you can use either this or `xcodegen generate`.

require 'xcodeproj'
require 'fileutils'

ROOT = File.expand_path('..', __dir__)
Dir.chdir(ROOT)

PROJECT_PATH = 'Pourtrait.xcodeproj'
DEPLOYMENT_TARGET = '17.0'
SWIFT_PACKAGES = [
  { url: 'https://github.com/googleads/swift-package-manager-google-mobile-ads', min: '12.0.0', product: 'GoogleMobileAds' },
  { url: 'https://github.com/googleads/swift-package-manager-google-user-messaging-platform', min: '3.0.0', product: 'UserMessagingPlatform' },
].freeze
REF_ONLY = %w[Info.plist .entitlements .storekit].freeze

FileUtils.rm_rf(PROJECT_PATH)
project = Xcodeproj::Project.new(PROJECT_PATH, false, 56)
project.root_object.attributes['LastUpgradeCheck'] = '1600'
project.root_object.attributes['BuildIndependentTargetsInParallel'] = '1'

project.build_configurations.each do |config|
  config.build_settings.merge!(
    'IPHONEOS_DEPLOYMENT_TARGET' => DEPLOYMENT_TARGET,
    'SWIFT_VERSION' => '5.0',
    'TARGETED_DEVICE_FAMILY' => '1',
    'MARKETING_VERSION' => '1.0.0',
    'CURRENT_PROJECT_VERSION' => '1',
    'DEVELOPMENT_TEAM' => '',
    'CODE_SIGN_STYLE' => 'Automatic',
    'SDKROOT' => 'iphoneos',
    'CLANG_ENABLE_MODULES' => 'YES',
    'ENABLE_USER_SCRIPT_SANDBOXING' => 'YES',
  )
  config.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG $(inherited)' if config.name == 'Debug'
  config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = config.name == 'Debug' ? '-Onone' : '-O'
  config.build_settings['ONLY_ACTIVE_ARCH'] = 'YES' if config.name == 'Debug'
end

# Adds every file under `dir` to `group`, mirroring folders as groups, and puts each
# file in the right build phase for every target in `targets`.
def add_tree(group, dir, targets)
  Dir.children(dir).sort.each do |name|
    next if name.start_with?('.')
    path = File.join(dir, name)
    if File.directory?(path) && !name.end_with?('.xcassets')
      add_tree(group.new_group(name, name), path, targets)
      next
    end

    ref = group.new_reference(name)
    next if REF_ONLY.any? { |suffix| name == suffix || name.end_with?(suffix) }

    targets.each do |target|
      if name.end_with?('.swift')
        target.source_build_phase.add_file_reference(ref, true)
      elsif name.end_with?('.xcassets', '.xcprivacy', '.json')
        target.resources_build_phase.add_file_reference(ref, true)
      end
    end
  end
end

# --- App target ------------------------------------------------------------
app = project.new_target(:application, 'Pourtrait', :ios, DEPLOYMENT_TARGET, nil, :swift)
app.build_configurations.each do |config|
  config.build_settings.merge!(
    'PRODUCT_BUNDLE_IDENTIFIER' => 'com.pourtrait.app',
    'PRODUCT_NAME' => '$(TARGET_NAME)',
    'INFOPLIST_FILE' => 'Pourtrait/Info.plist',
    'GENERATE_INFOPLIST_FILE' => 'NO',
    'CODE_SIGN_ENTITLEMENTS' => 'Pourtrait/Pourtrait.entitlements',
    'ASSETCATALOG_COMPILER_APPICON_NAME' => 'AppIcon',
    'ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME' => 'AccentColor',
    'ENABLE_PREVIEWS' => 'YES',
    'OTHER_LDFLAGS' => '$(inherited) -ObjC',
    'LD_RUNPATH_SEARCH_PATHS' => '$(inherited) @executable_path/Frameworks',
    'SWIFT_VERSION' => '5.0',
    'TARGETED_DEVICE_FAMILY' => '1',
  )
end

# --- Live Activity widget extension ----------------------------------------
widgets = project.new_target(:app_extension, 'PourtraitWidgets', :ios, DEPLOYMENT_TARGET, nil, :swift)
widgets.build_configurations.each do |config|
  config.build_settings.merge!(
    'PRODUCT_BUNDLE_IDENTIFIER' => 'com.pourtrait.app.widgets',
    'PRODUCT_NAME' => '$(TARGET_NAME)',
    'INFOPLIST_FILE' => 'PourtraitWidgets/Info.plist',
    'GENERATE_INFOPLIST_FILE' => 'NO',
    'CODE_SIGN_ENTITLEMENTS' => 'PourtraitWidgets/PourtraitWidgets.entitlements',
    'SKIP_INSTALL' => 'YES',
    'APPLICATION_EXTENSION_API_ONLY' => 'YES',
    'LD_RUNPATH_SEARCH_PATHS' => '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks',
    'SWIFT_VERSION' => '5.0',
    'TARGETED_DEVICE_FAMILY' => '1',
  )
end
# Swift auto-links Foundation, SwiftUI and WidgetKit, so drop the SDK-version-pinned
# framework references new_target adds; they'd show as missing on other Xcode versions.
[app, widgets].each do |target|
  target.frameworks_build_phase.files.to_a.each do |build_file|
    target.frameworks_build_phase.remove_build_file(build_file)
  end
end
project.frameworks_group.recursive_children.grep(Xcodeproj::Project::Object::PBXFileReference).each(&:remove_from_project)
project.frameworks_group.remove_from_project

# --- Files -----------------------------------------------------------------
add_tree(project.main_group.new_group('Pourtrait', 'Pourtrait'), 'Pourtrait', [app])
add_tree(project.main_group.new_group('PourtraitWidgets', 'PourtraitWidgets'), 'PourtraitWidgets', [widgets])
add_tree(project.main_group.new_group('Shared', 'Shared'), 'Shared', [app, widgets])
project.main_group.new_reference('project.yml')
project.main_group.new_reference('README.md')

# --- Embed the extension in the app ----------------------------------------
app.add_dependency(widgets)
embed = app.new_copy_files_build_phase('Embed Foundation Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
embed_file = embed.add_file_reference(widgets.product_reference, true)
embed_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

# --- Swift packages (Google Mobile Ads + consent SDK) ----------------------
SWIFT_PACKAGES.each do |pkg|
  ref = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
  ref.repositoryURL = pkg[:url]
  ref.requirement = { 'kind' => 'upToNextMajorVersion', 'minimumVersion' => pkg[:min] }
  project.root_object.package_references << ref

  dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  dep.package = ref
  dep.product_name = pkg[:product]
  app.package_product_dependencies << dep

  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = dep
  app.frameworks_build_phase.files << build_file
end

project.sort(groups_position: :above)
project.save

# --- Shared scheme with StoreKit testing -----------------------------------
scheme = Xcodeproj::XCScheme.new
scheme.configure_with_targets(app, nil, launch_target: true)
scheme.launch_action.xml_element.add_element(
  'StoreKitConfigurationFileReference',
  'identifier' => '../../Pourtrait/Configuration.storekit'
)
scheme.save_as(PROJECT_PATH, 'Pourtrait', true)

puts "Wrote #{PROJECT_PATH}"
