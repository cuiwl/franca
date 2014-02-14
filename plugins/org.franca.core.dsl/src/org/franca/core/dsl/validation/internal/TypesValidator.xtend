/*******************************************************************************
 * Copyright (c) 2012 itemis AG (http://www.itemis.de).
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *******************************************************************************/
package org.franca.core.dsl.validation.internal;

import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EStructuralFeature
import org.franca.core.contracts.IssueCollector
import org.franca.core.contracts.TypeIssue
import org.franca.core.contracts.TypeSystem
import org.franca.core.framework.FrancaHelpers
import org.franca.core.franca.FConstantDef
import org.franca.core.franca.FExpression
import org.franca.core.franca.FInitializer
import org.franca.core.franca.FTypeRef
import org.franca.core.franca.FCompoundInitializer
import org.franca.core.franca.FStructType
import org.franca.core.franca.FBracketInitializer
import org.franca.core.franca.FArrayType
import org.franca.core.franca.FMapType
import org.franca.core.franca.FInitializerExpression

import static org.franca.core.franca.FrancaPackage$Literals.*
import static extension org.franca.core.FrancaModelExtensions.*
import static extension org.franca.core.framework.FrancaHelpers.*

class TypesValidator {

	def static checkConstantType (ValidationMessageReporter reporter, FConstantDef constantDef) {
		checkConstantRHS(constantDef.rhs, constantDef.type,
			reporter, constantDef, FCONSTANT_DEF__RHS, -1
		)
	}
	
	def private static void checkConstantRHS (
		FInitializerExpression rhs,
		FTypeRef typeLHS,
		ValidationMessageReporter reporter,
		EObject ctxt,
		EStructuralFeature feature,
		int index
	) {
		switch (rhs) {
			FExpression: {
				checkExpression(reporter, rhs, typeLHS, ctxt, feature, index)
			}
			FInitializer: {
				checkInitializer(rhs, typeLHS, reporter, ctxt, feature, index)
			}
		}
	}
	
	def private static dispatch checkInitializer (
		FBracketInitializer rhs,
		FTypeRef type,
		ValidationMessageReporter reporter,
		EObject ctxt,
		EStructuralFeature feature,
		int index
	) {
		if (! (type.isArray || type.isMap)) {
			reporter.reportError(
					"invalid initializer in constant definition (expected " +
						FrancaHelpers::getTypeString(type) + ")",
					ctxt, feature);
			return;
		}
		
		if (type.isArray) {
			val t = type.actualDerived as FArrayType
			for(e : rhs.elements) {
				val idx = rhs.elements.indexOf(e)
				if (e.second!=null) {
					reporter.reportError(
							"invalid initializer for array element",
							rhs, FBRACKET_INITIALIZER__ELEMENTS, idx);
				} else {
					checkConstantRHS(e.first,
						t.elementType,
						reporter, e, FELEMENT_INITIALIZER__FIRST, -1
					)
				}
			}
		} else if (type.isMap) {
			val t = type.actualDerived as FMapType
			for(e : rhs.elements) {
				val idx = rhs.elements.indexOf(e)
				if (e.second==null) {
					reporter.reportError(
							"invalid initializer for map element",
							rhs, FBRACKET_INITIALIZER__ELEMENTS, idx);
				} else {
					checkConstantRHS(e.first,
						t.keyType,
						reporter, e, FELEMENT_INITIALIZER__FIRST, -1
					)
					checkConstantRHS(e.second,
						t.valueType,
						reporter, e, FELEMENT_INITIALIZER__SECOND, -1
					)
				}
			}
		}
	}
	
	def private static dispatch checkInitializer (
		FCompoundInitializer rhs,
		FTypeRef type,
		ValidationMessageReporter reporter,
		EObject ctxt,
		EStructuralFeature feature,
		int index
	) {
		if (! type.isCompound) {
			reporter.reportError(
					"invalid compound initializer in constant definition (expected " +
						FrancaHelpers::getTypeString(type) + ")",
					ctxt, feature, index);
			return;
		}
		
		if (type.isStruct) {
			val t = type.actualDerived as FStructType
			val elems = t.getAllElements
			
			// check if there are initializers for all struct elements
			val fields = rhs.elements.map[element]
			for(e : elems) {
				if (! fields.contains(e)) {
					reporter.reportError(
							"initializer for element '" + e.name + "' missing",
							ctxt, feature, index);
				}
			}
			
			// check the types for all initializers
			for(e : rhs.elements) {
				checkConstantRHS(e.value, e.element.type,
					reporter, e, FFIELD_INITIALIZER__VALUE, -1
				)
			}
		} else if (type.isUnion) {
			if (rhs.elements.size!=1) {
				reporter.reportError(
						"union initializer must have exactly one element",
						ctxt, feature, index);
			}

			// check type
			val e = rhs.elements.get(0)
			checkConstantRHS(e.value, e.element.type,
				reporter, e, FFIELD_INITIALIZER__VALUE, 0
			)
		}
	}

	def private static dispatch checkInitializer (
		FInitializer rhs,
		FTypeRef type,
		ValidationMessageReporter reporter,
		EObject ctxt,
		EStructuralFeature feature,
		int index
	) {
		throw new RuntimeException("Unknown FInitializer type '" + rhs.class.toString + "'")
	}
	

	def static boolean checkExpression (
			ValidationMessageReporter reporter,
			FExpression expr,
			FTypeRef expected,
			EObject loc, EStructuralFeature feat)
	{
		checkExpression(reporter, expr, expected, loc, feat, -1)
	}

	def private static boolean checkExpression (
			ValidationMessageReporter reporter,
			FExpression expr,
			FTypeRef expected,
			EObject loc, EStructuralFeature feat, int index)
	{
		val ts = new TypeSystem
		val issues = new IssueCollector
		val type = ts.checkType(expr, expected, issues, loc, feat)
		if (type==null) {
			if (issues.issues.empty) {
				// no issues, report a generic error message
				reporter.reportError("invalid expression", loc, feat)
			} else {
				for(TypeIssue ti : issues.issues) {
					reporter.reportError(ti.message, ti.location, ti.feature)
				}
			}
		}
		type!=null
	}
}

