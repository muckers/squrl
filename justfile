# justfile for squrl - Rust URL shortener
# Modularized with imports from just/ directory

# Import all module files
import 'just/build.just'
import 'just/development.just'
import 'just/deployment.just'  
import 'just/testing.just'
import 'just/validation.just'
import 'just/utilities.just'

# Default recipe - show help
default:
    @just --list