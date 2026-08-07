import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getAuth } from "firebase-admin/auth";
import {
  getFirestore,
  FieldValue,
} from "firebase-admin/firestore";
import { initializeApp } from "firebase-admin/app";
import { randomUUID } from "crypto";

initializeApp();

const db = getFirestore();

export const createParticipant = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "Debes iniciar sesión."
    );
  }

  const adminDoc = await db
    .collection("admins")
    .doc(request.auth.uid)
    .get();

  if (!adminDoc.exists) {
    throw new HttpsError(
      "permission-denied",
      "Solo el administrador puede crear usuarios."
    );
  }

  const displayName =
    String(request.data.displayName ?? "").trim();

  const password =
    String(request.data.password ?? "");

  if (!displayName) {
    throw new HttpsError(
      "invalid-argument",
      "Nombre obligatorio."
    );
  }

  if (password.length < 6) {
    throw new HttpsError(
      "invalid-argument",
      "La contraseña debe tener al menos 6 caracteres."
    );
  }

  const loginKey = displayName.toLowerCase();

  if (
    loginKey.includes("/") ||
    loginKey === "." ||
    loginKey === ".."
  ) {
    throw new HttpsError(
      "invalid-argument",
      "Nombre no válido."
    );
  }

  const aliasRef = db
    .collection("loginAliases")
    .doc(loginKey);

  const existingAlias = await aliasRef.get();

  if (existingAlias.exists) {
    throw new HttpsError(
      "already-exists",
      "Ya existe una cuenta con ese nombre."
    );
  }

  const internalEmail =
    `p-${randomUUID()}@fiesta.example.com`;

  const user = await getAuth().createUser({
    email: internalEmail,
    password,
    displayName,
  });

  try {
    const batch = db.batch();

    batch.set(
      db.collection("profiles").doc(user.uid),
      {
        displayName,
        createdAt: FieldValue.serverTimestamp(),
      }
    );

    batch.set(aliasRef, {
      uid: user.uid,
      email: internalEmail,
    });

    await batch.commit();

    return {
      uid: user.uid,
      displayName,
    };
  } catch (error) {
    await getAuth().deleteUser(user.uid);
    throw error;
  }
});