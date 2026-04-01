#!/usr/bin/env ruby

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../example-app/ios/App/App.xcodeproj', __dir__)
TARGET_NAME = 'ExampleWidgetExtension'
TARGET_DEPLOYMENT = '16.2'
EXTENSION_FOLDER = 'ExampleWidgetExtension'
APP_GROUP = 'group.app.capgo.widgetkit.exampleapp.widgetkit'

project = Xcodeproj::Project.open(PROJECT_PATH)
app_target = project.targets.find { |target| target.name == 'App' }
abort('App target not found') unless app_target

widget_target = project.targets.find { |target| target.name == TARGET_NAME }
unless widget_target
  widget_target = project.new_target(:app_extension, TARGET_NAME, :ios, TARGET_DEPLOYMENT)
  widget_target.product_type = 'com.apple.product-type.app-extension'
end

group = project.main_group.find_subpath(EXTENSION_FOLDER, true)
group.set_source_tree('SOURCE_ROOT')

source_path = "#{EXTENSION_FOLDER}/ExampleWidgetBundle.swift"
plist_path = "#{EXTENSION_FOLDER}/Info.plist"
entitlements_path = "#{EXTENSION_FOLDER}/ExampleWidgetExtension.entitlements"

source_ref = group.files.find { |file| file.path == source_path } || group.new_file(source_path)
plist_ref = group.files.find { |file| file.path == plist_path } || group.new_file(plist_path)
entitlements_ref = group.files.find { |file| file.path == entitlements_path } || group.new_file(entitlements_path)

unless widget_target.source_build_phase.files_references.include?(source_ref)
  widget_target.add_file_references([source_ref])
end

cap_app_package = project.root_object.package_references.find { |package| package.display_name == 'CapApp-SPM' }
abort('CapApp-SPM package reference not found') unless cap_app_package

package_dependency = widget_target.package_product_dependencies.find { |dependency| dependency.product_name == 'CapApp-SPM' }
unless package_dependency
  package_dependency = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  package_dependency.product_name = 'CapApp-SPM'
  package_dependency.package = cap_app_package
  widget_target.package_product_dependencies << package_dependency
end

unless widget_target.frameworks_build_phase.files.any? { |file| file.product_ref == package_dependency }
  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = package_dependency
  widget_target.frameworks_build_phase.files << build_file
end

widget_target.build_configurations.each do |config|
  config.build_settings['INFOPLIST_FILE'] = plist_path
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = entitlements_path
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = TARGET_DEPLOYMENT
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = "app.capgo.widgetkit.exampleapp.widgetextension"
  config.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
  config.build_settings['SKIP_INSTALL'] = 'YES'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  config.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = config.name == 'Debug' ? 'DEBUG' : ''
  config.build_settings['ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS'] = 'NO'
end

app_target.add_dependency(widget_target) unless app_target.dependencies.any? { |dependency| dependency.target == widget_target }

embed_phase = app_target.copy_files_build_phases.find { |phase| phase.name == 'Embed App Extensions' } ||
              app_target.new_copy_files_build_phase('Embed App Extensions')
embed_phase.symbol_dst_subfolder_spec = :plug_ins

product_ref = widget_target.product_reference
unless embed_phase.files_references.include?(product_ref)
  build_file = embed_phase.add_file_reference(product_ref, true)
  build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
end

project.save

puts "Configured #{TARGET_NAME} in #{PROJECT_PATH}"
