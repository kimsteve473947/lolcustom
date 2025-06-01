#!/bin/bash
cp -f ios/fix_patches/fixed_storage.swift ios/Pods/FirebaseStorage/FirebaseStorage/Sources/Storage.swift
chmod 644 ios/Pods/FirebaseStorage/FirebaseStorage/Sources/Storage.swift
